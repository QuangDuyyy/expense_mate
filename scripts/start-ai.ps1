param([string]$DeviceId = '')
. (Join-Path $PSScriptRoot 'environment.ps1')
Initialize-Tools
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Install Node.js LTS (22 or newer): https://nodejs.org/' }
$major = [int]((& node -p 'parseInt(process.versions.node)') | Select-Object -First 1)
if ($major -lt 22) { throw 'Node.js 22 or newer is required.' }
$sdk = Get-AndroidSdk
$adb = Join-Path $sdk 'platform-tools/adb.exe'
$lines = & $adb devices
$devices = @($lines | Where-Object { $_ -match '^\S+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
if (-not $DeviceId) {
    if ($devices.Count -eq 1) { $DeviceId = $devices[0] }
    elseif ($devices.Count -gt 1) { & $adb devices; $DeviceId = Read-Host 'Enter Android device ID' }
    else { throw 'No authorised Android device. Connect USB and allow debugging first.' }
}
if ($devices -notcontains $DeviceId) { throw 'Selected Android device is not authorised or connected.' }
Invoke-Checked $adb @('-s', $DeviceId, 'reverse', 'tcp:8787', 'tcp:8787')
$local = Join-Path $script:ProjectRoot '.local'
New-Item -ItemType Directory -Force -Path $local | Out-Null
$pairingPath = Join-Path $local 'pairing-token.txt'
if (-not (Test-Path $pairingPath)) {
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    Write-Utf8 $pairingPath ([Convert]::ToBase64String($bytes))
}
$env:EXPENSEMATE_TOKEN = [System.IO.File]::ReadAllText($pairingPath).Trim()
if (-not $env:GEMINI_API_KEY) {
    $secureKey = Read-Host 'Paste Gemini API key (hidden; never saved)' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
    try { $env:GEMINI_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer).Trim() }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
if (-not $env:GEMINI_API_KEY) { throw 'API key is empty.' }
if (-not $env:GEMINI_MODEL) { $env:GEMINI_MODEL = 'gemini-3.1-flash-lite' }
$env:EXPENSEMATE_HOST = '127.0.0.1'
Write-Host ''
Write-Host 'PHONE > Settings > AI connection:'
Write-Host 'URL: http://127.0.0.1:8787'
Write-Host ('Pairing code: ' + $env:EXPENSEMATE_TOKEN)
Write-Host 'The pairing code is NOT the Gemini API key. Keep this window open.'
try { Invoke-Checked 'node' @((Join-Path $script:ProjectRoot 'server/server.mjs')) }
finally { Remove-Item Env:GEMINI_API_KEY -ErrorAction SilentlyContinue; Remove-Item Env:EXPENSEMATE_TOKEN -ErrorAction SilentlyContinue }
