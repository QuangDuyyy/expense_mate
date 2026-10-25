param([string]$DeviceId = '')
. (Join-Path $PSScriptRoot 'environment.ps1')
Initialize-Tools
$adb = Join-Path (Get-AndroidSdk) 'platform-tools/adb.exe'
if (-not $DeviceId) {
    $lines = & $adb devices
    $devices = @($lines | Where-Object { $_ -match '^\S+\s+device$' } | ForEach-Object { ($_ -split '\s+')[0] })
    if ($devices.Count -ne 1) { & $adb devices; $DeviceId = Read-Host 'Enter device ID' }
    else { $DeviceId = $devices[0] }
}
$directory = Join-Path $script:ProjectRoot 'docs/evidence'
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$steps = @(
    @{ file = 'light.png'; instruction = 'Open HOME with sample expenses in LIGHT theme.' },
    @{ file = 'dark.png'; instruction = 'Switch to DARK theme and open HOME with the same data.' },
    @{ file = 'review.png'; instruction = 'Open a REAL receipt review, show extracted fields. Hide personal details.' },
    @{ file = 'charts.png'; instruction = 'Open weekly CHARTS with the receipt included.' },
    @{ file = 'ai.png'; instruction = 'Show a SUCCESSFUL Gemini suggestion. Do not show API keys or pairing code.' }
)
foreach ($step in $steps) {
    Write-Host $step.instruction
    [void](Read-Host 'Press Enter when this screen is visible on the phone')
    $remote = '/sdcard/expensemate_evidence_' + [guid]::NewGuid().ToString('N') + '.png'
    try {
        Invoke-Checked $adb @('-s', $DeviceId, 'shell', 'screencap', '-p', $remote)
        Invoke-Checked $adb @('-s', $DeviceId, 'pull', $remote, (Join-Path $directory $step.file))
    } finally { & $adb -s $DeviceId shell rm -f $remote | Out-Null }
}
Write-Host 'Evidence saved. Open docs/report.html and print to PDF after filling student/repository fields.'
