$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:Utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Utf8([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $script:Utf8)
}
function Initialize-Tools {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter not found on PATH.' }
    $javaCandidates = @(
        'C:\Program Files\Android\Android Studio1\jbr',
        'C:\Program Files\Android\Android Studio\jbr',
        $env:JAVA_HOME
    )
    foreach ($candidate in $javaCandidates) {
        if ($candidate -and (Test-Path (Join-Path $candidate 'bin/java.exe'))) {
            $env:JAVA_HOME = $candidate
            break
        }
    }
    Set-Location $script:ProjectRoot
}
function Get-AndroidSdk {
    $candidates = @()
    $local = Join-Path $script:ProjectRoot 'android/local.properties'
    if (Test-Path $local) {
        $line = Get-Content $local | Where-Object { $_ -match '^sdk.dir=' } | Select-Object -First 1
        if ($line) { $candidates += ($line.Substring(8).Replace('\\','\').Replace('\:',':')) }
    }
    $candidates += @($env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, (Join-Path $env:LOCALAPPDATA 'Android/sdk'), 'D:\Android\Sdk')
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path (Join-Path $candidate 'platform-tools/adb.exe'))) { return $candidate }
    }
    throw 'Android SDK not found. Run flutter doctor -v and check android/local.properties.'
}
function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed (exit $LASTEXITCODE)." }
}
