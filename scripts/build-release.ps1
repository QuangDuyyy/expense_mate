. (Join-Path $PSScriptRoot 'environment.ps1')
Initialize-Tools
& (Join-Path $PSScriptRoot 'configure-android.ps1')
$keytool = Join-Path $env:JAVA_HOME 'bin/keytool.exe'
if (-not (Test-Path $keytool)) { throw 'Cannot find keytool in JAVA_HOME. Run flutter doctor -v.' }
$secrets = Join-Path $script:ProjectRoot '.local'
New-Item -ItemType Directory -Force -Path $secrets | Out-Null
$keystore = Join-Path $secrets 'expense-mate-release.jks'
$propertiesPath = Join-Path $script:ProjectRoot 'android/key.properties'
if (-not (Test-Path $propertiesPath)) {
    if (-not (Test-Path $keystore)) {
        Write-Host 'Create your signing key. Remember the password; do not send it in chat.'
        & $keytool -genkeypair -v -keystore $keystore -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias expensemate
        if ($LASTEXITCODE -ne 0) { throw 'Key creation failed.' }
    }
    Write-Host 'Enter the existing keystore password below. The private key password must match the keystore password.'
    $secret = Read-Host 'Keystore password (hidden)' -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    try { $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    # Keytool reads password from environment, not from a process argument.
    $env:EXPENSEMATE_STORE_PASSWORD = $password
    try {
        & $keytool -list -keystore $keystore -alias expensemate '-storepass:env' 'EXPENSEMATE_STORE_PASSWORD' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Wrong keystore password.' }
    } finally { Remove-Item Env:EXPENSEMATE_STORE_PASSWORD -ErrorAction SilentlyContinue }
    function Escape-Property([string]$value) {
        $builder = New-Object System.Text.StringBuilder
        foreach ($char in $value.ToCharArray()) {
            $code = [int][char]$char
            if ($code -gt 126 -or $code -lt 32) { [void]$builder.Append(('\u{0:x4}' -f $code)) }
            elseif ($char -eq '\') { [void]$builder.Append('\\') }
            elseif ($char -eq ' ' -or $char -eq '=' -or $char -eq ':' -or $char -eq '#' -or $char -eq '!') { [void]$builder.Append('\').Append($char) }
            else { [void]$builder.Append($char) }
        }
        return $builder.ToString()
    }
    $escaped = Escape-Property $password
    $storePath = $keystore.Replace('\','/')
    Write-Utf8 $propertiesPath "storePassword=$escaped`nkeyPassword=$escaped`nkeyAlias=expensemate`nstoreFile=$storePath`n"
    $password = $null
}
Invoke-Checked 'flutter' @('pub', 'get')
Invoke-Checked 'flutter' @('analyze')
Invoke-Checked 'flutter' @('test')
Invoke-Checked 'flutter' @('build', 'apk', '--release')
$output = Join-Path $script:ProjectRoot 'release'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$apk = Join-Path $output 'app-release.apk'
Copy-Item 'build/app/outputs/flutter-apk/app-release.apk' $apk -Force
$hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLower()
Write-Utf8 (Join-Path $output 'app-release.apk.sha256') ($hash + '  app-release.apk')
Write-Host ('Release APK ready: ' + $apk)
Write-Host 'Install separately from debug. Export/import data in Settings before switching.'
Write-Host 'Back up .local/expense-mate-release.jks and android/key.properties privately. Never publish them.'
