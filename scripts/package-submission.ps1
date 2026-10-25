. (Join-Path $PSScriptRoot 'environment.ps1')
Initialize-Tools
Invoke-Checked 'flutter' @('pub', 'get')
Invoke-Checked 'flutter' @('analyze')
Invoke-Checked 'flutter' @('test')
if (Get-Command node -ErrorAction SilentlyContinue) { Invoke-Checked 'node' @('--test', 'server/server.test.mjs', 'server/features.test.mjs', 'server/vision.test.mjs', 'server/diagnostics.test.mjs') }
$release = Join-Path $script:ProjectRoot 'release'
New-Item -ItemType Directory -Force -Path $release | Out-Null
$sourceZip = Join-Path $release 'ExpenseMate_Source_v1.2.1.zip'
if (Test-Path $sourceZip) { Remove-Item -LiteralPath $sourceZip -Force }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($sourceZip, [System.IO.Compression.ZipArchiveMode]::Create)
$count = 0
try {
    foreach ($file in Get-ChildItem $script:ProjectRoot -File -Recurse -Force) {
        $relative = $file.FullName.Substring($script:ProjectRoot.Length + 1).Replace('\','/')
        if ($relative -match '(^|/)(\.git|\.dart_tool|\.gradle|\.idea|\.local|node_modules|build|release|expense_mate-backups)(/|$)' -or
            $relative -match '(?i)(^|/)(local.properties|key.properties|\.env[^/]*|pairing-token.txt)$' -or
            $relative -match '(?i)\.(jks|keystore|log|zip|iml)$' -or
            $relative -in @('.flutter-plugins', '.flutter-plugins-dependencies', '.packages', 'update-manifest.json')) { continue }
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, 'expense_mate/' + $relative)
        $count++
    }
} finally { $zip.Dispose() }
Write-Host "Public source package: $sourceZip ($count files)"
Write-Host 'Before publishing: inspect source ZIP, README links, screenshots and report; do not include private credentials.'
