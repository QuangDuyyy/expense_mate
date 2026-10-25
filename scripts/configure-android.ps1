. (Join-Path $PSScriptRoot 'environment.ps1')
Initialize-Tools
$gradlePath = Join-Path $script:ProjectRoot 'android/app/build.gradle.kts'
if (-not (Test-Path $gradlePath)) { throw 'Expected Kotlin Gradle template. Run 01_Setup.cmd first.' }
$gradle = [System.IO.File]::ReadAllText($gradlePath)
$gradle = $gradle -replace 'minSdk\s*=\s*flutter.minSdkVersion', 'minSdk = 23'
# Preserve applicationId and namespace so the existing debug install keeps its data.
if (-not $gradle.Contains('// ExpenseMate signing v1')) {
    if ($gradle -notmatch 'signingConfig\s*=\s*signingConfigs.getByName\("debug"\)') {
        throw 'Unexpected release signing block; no automatic overwrite. Send android/app/build.gradle.kts for review.'
    }
    $gradle = $gradle -replace 'signingConfig\s*=\s*signingConfigs.getByName\("debug"\)', 'signingConfig = signingConfigs.findByName("expenseMateRelease")'
    $anchor = 'android {'
    $position = $gradle.IndexOf($anchor)
    if ($position -lt 0) { throw 'Cannot locate android block.' }
    $prefix = @'
// ExpenseMate signing v1
val expenseMateKeyFile = rootProject.file("key.properties")
val expenseMateKeys = java.util.Properties()
if (expenseMateKeyFile.exists()) {
    expenseMateKeyFile.inputStream().use { expenseMateKeys.load(it) }
}

'@
    # java.util can conflict with the Gradle java extension: explicit import + unqualified name.
    $prefix = $prefix.Replace('java.util.Properties()', 'Properties()')
    if (-not $gradle.Contains('import java.util.Properties')) { $gradle = "import java.util.Properties`n" + $gradle }
    $position = $gradle.IndexOf($anchor)
    $gradle = $gradle.Insert($position, $prefix + "`n")
    $buildTypes = @'
    signingConfigs {
        if (expenseMateKeyFile.exists()) {
            create("expenseMateRelease") {
                keyAlias = expenseMateKeys.getProperty("keyAlias")
                keyPassword = expenseMateKeys.getProperty("keyPassword")
                storeFile = file(expenseMateKeys.getProperty("storeFile"))
                storePassword = expenseMateKeys.getProperty("storePassword")
            }
        }
    }
    buildTypes {
'@
    $gradle = $gradle.Replace('    buildTypes {', $buildTypes)
    # Release gets a separate ID so debug data remains untouched. Never uninstall automatically.
    $gradle = $gradle.Replace('        release {', "        release {`n            applicationIdSuffix = `".release`"")
    if (-not $gradle.Contains('    buildTypes {') -or -not $gradle.Contains('applicationIdSuffix')) { throw 'Gradle patch failed.' }
}
Write-Utf8 $gradlePath $gradle
$manifestPath = Join-Path $script:ProjectRoot 'android/app/src/main/AndroidManifest.xml'
[xml]$manifest = [System.IO.File]::ReadAllText($manifestPath)
$ns = 'http://schemas.android.com/apk/res/android'
$app = $manifest.manifest.application
[void]$app.SetAttribute('label', $ns, '@string/expense_mate_app_name')
[void]$app.SetAttribute('icon', $ns, '@drawable/expense_mate_icon')
[void]$app.SetAttribute('networkSecurityConfig', $ns, '@xml/expense_mate_network')
[void]$app.SetAttribute('allowBackup', $ns, 'false')
if (-not ($manifest.manifest.SelectNodes('uses-permission') | Where-Object { $_.GetAttribute('name', $ns) -eq 'android.permission.INTERNET' })) {
    $permission = $manifest.CreateElement('uses-permission')
    [void]$permission.SetAttribute('name', $ns, 'android.permission.INTERNET')
    [void]$manifest.manifest.AppendChild($permission)
}
$manifest.Save($manifestPath)
$resource = Join-Path $script:ProjectRoot 'android/app/src/main/res'
New-Item -ItemType Directory -Force -Path (Join-Path $resource 'xml'), (Join-Path $resource 'drawable'), (Join-Path $resource 'values') | Out-Null
Copy-Item (Join-Path $script:ProjectRoot 'android-config/network_security_config.xml') (Join-Path $resource 'xml/expense_mate_network.xml') -Force
Copy-Item (Join-Path $script:ProjectRoot 'android-config/expense_mate_icon.xml') (Join-Path $resource 'drawable/expense_mate_icon.xml') -Force
Write-Utf8 (Join-Path $resource 'values/expense_mate_strings.xml') '<resources><string name="expense_mate_app_name">ExpenseMate</string></resources>'
$releaseValues = Join-Path $script:ProjectRoot 'android/app/src/release/res/values'
New-Item -ItemType Directory -Force -Path $releaseValues | Out-Null
Write-Utf8 (Join-Path $releaseValues 'expense_mate_strings.xml') '<resources><string name="expense_mate_app_name">ExpenseMate Release</string></resources>'
Write-Host 'Android configured: same debug ID, separate signed release ID, loopback-only HTTP.'
