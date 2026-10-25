. (Join-Path $PSScriptRoot 'environment.ps1')
Initialize-Tools
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter SDK not found. Open docs/01_CAI_DAT_WINDOWS.md first.'
}
if (-not (Test-Path (Join-Path $root 'android'))) {
  $temporaryProject = Join-Path ([System.IO.Path]::GetTempPath()) ('expense_mate_' + [guid]::NewGuid().ToString('N'))
  try {
    Invoke-Checked 'flutter' @('create', '--platforms=android', '--org=vn.edu.vku', '--project-name=expense_mate', '--no-pub', $temporaryProject)
    if ($LASTEXITCODE -ne 0) { throw 'flutter create failed.' }
    Copy-Item (Join-Path $temporaryProject 'android') $root -Recurse
    Copy-Item (Join-Path $temporaryProject '.metadata') $root
  } finally {
    if (Test-Path $temporaryProject) { Remove-Item $temporaryProject -Recurse -Force }
  }
}
$gradleKotlin = Join-Path $root 'android/app/build.gradle.kts'
$gradleGroovy = Join-Path $root 'android/app/build.gradle'
$encoding = New-Object System.Text.UTF8Encoding($false)
if (Test-Path $gradleKotlin) {
  $text = [System.IO.File]::ReadAllText($gradleKotlin)
  $text = $text -replace 'minSdk\s*=\s*flutter.minSdkVersion', 'minSdk = 23'
  [System.IO.File]::WriteAllText($gradleKotlin, $text, $encoding)
} elseif (Test-Path $gradleGroovy) {
  $text = [System.IO.File]::ReadAllText($gradleGroovy)
  $text = $text -replace 'minSdkVersion\s+flutter.minSdkVersion', 'minSdkVersion 23'
  [System.IO.File]::WriteAllText($gradleGroovy, $text, $encoding)
} else { throw 'Android Gradle template not found.' }
$manifestPath = Join-Path $root 'android/app/src/main/AndroidManifest.xml'
$manifest = [System.IO.File]::ReadAllText($manifestPath)
$manifest = $manifest -replace 'android:label="expense_mate"', 'android:label="ExpenseMate"'
[System.IO.File]::WriteAllText($manifestPath, $manifest, $encoding)
& (Join-Path $PSScriptRoot 'configure-android.ps1')
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed. Share the error output for help.' }
Write-Host 'Setup finished. Next: flutter analyze, flutter test, flutter run -d YOUR_ANDROID_DEVICE_ID'
