param([string]$BackupPath = '')
$ErrorActionPreference = 'Stop'
if (-not $BackupPath) { $BackupPath = Read-Host 'Paste the backup folder path printed by the updater' }
$BackupPath = $BackupPath.Trim('"')
$manifest = Get-Content (Join-Path $BackupPath 'rollback.json') -Raw | ConvertFrom-Json
$target = [System.IO.Path]::GetFullPath($manifest.target).TrimEnd('\')
if (-not (Test-Path (Join-Path $target 'pubspec.yaml'))) { throw 'Original project folder not found.' }
foreach ($entry in $manifest.files) {
    $dest = [System.IO.Path]::GetFullPath((Join-Path $target $entry.path))
    if (-not $dest.StartsWith($target + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid backup path.' }
    if ($entry.existed) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        Copy-Item -LiteralPath (Join-Path $BackupPath $entry.path) -Destination $dest -Force
    } elseif (Test-Path -LiteralPath $dest -PathType Leaf) { Remove-Item -LiteralPath $dest -Force }
}
Set-Location $target
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency refresh failed after restore.' }
Write-Host 'Source restored. Phone data and private keys were not changed.'
