param([string]$Target = '', [string]$Source = '')
$ErrorActionPreference = 'Stop'
if (-not $Source) { $Source = Split-Path -Parent $PSScriptRoot }
$Source = [System.IO.Path]::GetFullPath($Source).TrimEnd('\')
if (-not $Target) {
    $known = Join-Path $env:USERPROFILE 'Projects/ExpenseMate_Starter_v0.1.0/expense_mate'
    if ((Test-Path (Join-Path $known 'pubspec.yaml')) -and $known -ne $Source) { $Target = $known }
    else {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'Choose the EXISTING expense_mate folder (contains pubspec.yaml).'
        if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'Update cancelled.' }
        $Target = $dialog.SelectedPath
        $dialog.Dispose()
    }
}
$Target = [System.IO.Path]::GetFullPath($Target).TrimEnd('\')
if ($Source -eq $Target) { throw 'Extract the update separately; select your existing app as target.' }
if (-not (Test-Path (Join-Path $Target 'pubspec.yaml'))) { throw 'Target has no pubspec.yaml.' }
if ([System.IO.File]::ReadAllText((Join-Path $Target 'pubspec.yaml')) -notmatch '(?m)^name:\s*expense_mate\s*$') { throw 'Not an ExpenseMate project.' }
$metadata = Get-Content (Join-Path $Source 'update-manifest.json') -Raw | ConvertFrom-Json
if ($metadata.project -ne 'expense_mate') { throw 'Wrong update project.' }
$currentVersion = '0.1.0'
if (Test-Path (Join-Path $Target 'VERSION')) { $currentVersion = (Get-Content (Join-Path $Target 'VERSION') -Raw).Trim() }
if ([version]$currentVersion -ge [version]$metadata.version) { throw "Already at $currentVersion or newer. Update not applied." }
$prefixes = @('lib/', 'test/', 'scripts/', 'server/', 'docs/', 'android-config/', '.github/', 'release/')
function Assert-ManagedPath([string]$Relative) {
    if (-not $Relative -or $Relative.Contains('\') -or $Relative.Contains(':') -or
        $Relative.Split('/') -contains '..' -or [System.IO.Path]::IsPathRooted($Relative)) { throw 'Unsafe update path.' }
    $allowed = @('pubspec.yaml','README.md','VERSION','.gitignore','01_Setup.cmd','02_Check.cmd','03_Run.cmd','04_Validate.cmd','Start-App.cmd','Start-AI.cmd','Build-Release.cmd','Update-ExpenseMate.cmd','Restore-Source.cmd','Capture-Evidence.cmd','Package-Submission.cmd','CHANGELOG.md','update-manifest.json') -contains $Relative
    foreach ($prefix in $prefixes) { if ($Relative.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { $allowed = $true } }
    if (-not $allowed -or $Relative -match '(?i)(key\.properties|\.jks$|\.keystore$|pairing-token|(^|/)\.env(?:\.[^/]*)?$|node_modules|\.local)') { throw "Excluded path: $Relative" }
}
$newPaths = @($metadata.files | ForEach-Object { [string]$_.path })
foreach ($entry in $metadata.files) {
    $relative = [string]$entry.path
    Assert-ManagedPath $relative
    $file = Join-Path $Source $relative
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing update file: $relative" }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower() -ne $entry.sha256) { throw "Hash mismatch: $relative" }
}
# Remove only obsolete files explicitly owned by the previous release manifest.
# Untracked personal files and separately installed manager utilities are preserved.
$obsoletePaths = @()
$previousManifest = Join-Path $Target 'update-manifest.json'
if (Test-Path -LiteralPath $previousManifest) {
    $previous = Get-Content -LiteralPath $previousManifest -Raw | ConvertFrom-Json
    if ($previous.project -ne 'expense_mate') { throw 'Existing update manifest belongs to another project.' }
    foreach ($entry in $previous.files) {
        $relative = [string]$entry.path
        Assert-ManagedPath $relative
        if ($newPaths -notcontains $relative) { $obsoletePaths += $relative }
    }
}
# Detect active Flutter/Gradle commands explicitly referencing this workspace.
$active = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -and $_.ProcessId -ne $PID -and $_.Name -match '^(java|dart|flutter|node)\.exe$' -and
    $_.CommandLine.IndexOf($Target, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
})
if ($active.Count -gt 0) { throw 'App/AI process is active in this project. Stop the app build and AI with Ctrl+C, then retry.' }
$backupRoot = Join-Path (Split-Path -Parent $Target) 'expense_mate-backups'
$backup = Join-Path $backupRoot ((Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + [guid]::NewGuid().ToString('N').Substring(0,6))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
$tracked = $newPaths + $obsoletePaths + @('update-manifest.json',
    'pubspec.lock', 'android/app/build.gradle.kts', 'android/app/src/main/AndroidManifest.xml',
    'android/app/src/main/res/xml/expense_mate_network.xml',
    'android/app/src/main/res/drawable/expense_mate_icon.xml', 'android/app/src/main/res/values/expense_mate_strings.xml',
    'android/app/src/release/res/values/expense_mate_strings.xml')
$records = @()
foreach ($relative in ($tracked | Select-Object -Unique)) {
    $original = Join-Path $Target $relative
    $exists = Test-Path -LiteralPath $original -PathType Leaf
    $records += @{ path = $relative; existed = $exists }
    if ($exists) {
        $dest = Join-Path $backup $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -LiteralPath $original -Destination $dest -Force
    }
}
@{ target = $Target; previous_version = $currentVersion; files = $records } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $backup 'rollback.json') -Encoding UTF8
try {
    foreach ($entry in $metadata.files) {
        $destination = Join-Path $Target $entry.path
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath (Join-Path $Source $entry.path) -Destination $destination -Force
    }
    foreach ($relative in $obsoletePaths) {
        $obsoleteFile = Join-Path $Target $relative
        if (Test-Path -LiteralPath $obsoleteFile -PathType Leaf) { Remove-Item -LiteralPath $obsoleteFile -Force }
    }
    Copy-Item (Join-Path $Source 'update-manifest.json') (Join-Path $Target 'update-manifest.json') -Force
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Target 'scripts/setup.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Setup failed. Source backup is available.' }
    Push-Location $Target
    try {
        & flutter analyze
        if ($LASTEXITCODE -ne 0) { throw 'Flutter analyze failed.' }
        & flutter test
        if ($LASTEXITCODE -ne 0) { throw 'Flutter tests failed.' }
        if (Get-Command node -ErrorAction SilentlyContinue) {
            & node --test server/server.test.mjs server/features.test.mjs server/vision.test.mjs server/diagnostics.test.mjs
            if ($LASTEXITCODE -ne 0) { throw 'AI service tests failed.' }
        }
    } finally { Pop-Location }
    Write-Host "Updated $currentVersion -> $($metadata.version)"
    Write-Host "Source backup: $backup"
    Write-Host ("Replaced managed source; retired files: " + $obsoletePaths.Count)
    Write-Host "Run the SAME app folder: $Target\Start-App.cmd"
    Write-Host 'Phone data, Android SDK settings, signing keys and local AI pairing were preserved.'
} catch {
    $failure = $_
    foreach ($record in $records) {
        $destination = Join-Path $Target $record.path
        if ($record.existed) { Copy-Item -LiteralPath (Join-Path $backup $record.path) -Destination $destination -Force }
        elseif (Test-Path -LiteralPath $destination -PathType Leaf) { Remove-Item -LiteralPath $destination -Force }
    }
    Write-Host "Source restored after update failure. Backup: $backup"
    Write-Host 'pubspec.lock may have changed; run flutter pub get before running the restored source.'
    throw $failure
}
