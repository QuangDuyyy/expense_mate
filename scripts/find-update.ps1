# Called at app startup. First upgrade is installed by the standalone update entrypoint.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$versionPath = Join-Path $root 'VERSION'
if (-not (Test-Path $versionPath)) { return }
$current = [version](Get-Content $versionPath -Raw).Trim()
Add-Type -AssemblyName System.IO.Compression.FileSystem
$folders = @((Join-Path $env:USERPROFILE 'Projects'), (Join-Path $env:USERPROFILE 'Downloads'), (Join-Path (Split-Path -Parent $root) 'expense_mate-updates'))
$candidates = @()
foreach ($folder in $folders) {
    if (-not (Test-Path -LiteralPath $folder)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $folder -File -Filter 'ExpenseMate*.zip') {
        if ($file.Length -gt 52428800) { continue }
        $archive = $null
        try {
            $archive = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
            $entry = $archive.GetEntry('expense_mate/update-manifest.json')
            if (-not $entry -or $entry.Length -gt 1048576) { continue }
            $reader = New-Object System.IO.StreamReader($entry.Open())
            try { $meta = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
            if ($meta.project -eq 'expense_mate' -and [version]$meta.version -gt $current) {
                $candidates += @{ Path = $file.FullName; Version = [version]$meta.version }
            }
        } catch { Write-Host ('Skipped unreadable update ZIP: ' + $file.Name) }
        finally { if ($archive) { $archive.Dispose() } }
    }
}
if ($candidates.Count -eq 0) { Write-Host ('No newer ExpenseMate update ZIP found. Installed version: ' + $current); return }
$newest = $candidates | Sort-Object { $_.Version } -Descending | Select-Object -First 1
$staging = Join-Path (Split-Path -Parent $root) ('expense_mate-updates/staging_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $staging | Out-Null
$archive = [System.IO.Compression.ZipFile]::OpenRead($newest.Path)
try {
    if ($archive.Entries.Count -gt 500) { throw 'Too many update files.' }
    $total = 0L
    foreach ($entry in $archive.Entries) {
        $total += $entry.Length
        if ($total -gt 83886080) { throw 'Update expands beyond 80 MB.' }
        $full = [System.IO.Path]::GetFullPath((Join-Path $staging $entry.FullName))
        if (-not $full.StartsWith($staging + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe ZIP path.' }
    }
} finally { $archive.Dispose() }
try {
    Expand-Archive -LiteralPath $newest.Path -DestinationPath $staging -Force
    Write-Host ('Applying update ' + $newest.Version + ' before launching the app...')
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $staging 'expense_mate/scripts/update.ps1') -Target $root -Source (Join-Path $staging 'expense_mate')
    if ($LASTEXITCODE -ne 0) { throw 'Automatic update failed. App was not launched; review the error above.' }
    $processed = Join-Path (Split-Path -Parent $root) 'expense_mate-updates/processed'
    New-Item -ItemType Directory -Force -Path $processed | Out-Null
    $destination = Join-Path $processed ($newest.Version.ToString() + '_' + [guid]::NewGuid().ToString('N').Substring(0,6) + '.zip')
    try { Move-Item -LiteralPath $newest.Path -Destination $destination }
    catch { Write-Host 'Update applied. ZIP could not be archived; installed VERSION prevents reapplying it.' }
} finally {
    if (Test-Path $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
