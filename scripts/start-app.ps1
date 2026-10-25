param([string]$DeviceId = '')
. (Join-Path $PSScriptRoot 'environment.ps1')
Initialize-Tools
& (Join-Path $PSScriptRoot 'find-update.ps1')
if (-not (Test-Path 'android/app/build.gradle.kts')) { & (Join-Path $PSScriptRoot 'setup.ps1') }
if (-not (Test-Path 'android/app/src/main/res/xml/expense_mate_network.xml')) { & (Join-Path $PSScriptRoot 'configure-android.ps1') }
Invoke-Checked 'flutter' @('pub', 'get')
if ($DeviceId) { Invoke-Checked 'flutter' @('run', '-d', $DeviceId) }
else { Invoke-Checked 'flutter' @('run') }
