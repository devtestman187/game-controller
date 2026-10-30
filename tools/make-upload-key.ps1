# Makes the Google Play upload key for Thumb Party and Thumb Party TV (PRD v2 M8), once.
#
#   powershell -ExecutionPolicy Bypass -File tools\make-upload-key.ps1
#
# keytool asks for a password: choose a strong one and keep it in your password manager. The key
# and its key.properties go to %USERPROFILE%\.thumbparty, outside the repository, and are never
# committed. Back up that folder: with Play App Signing a lost upload key can be reset, but it takes
# a request to Google and a few days.
#
# Afterwards the script prints the four GitHub secrets the release workflow needs, as gh commands.

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:USERPROFILE '.thumbparty'
$keystore = Join-Path $dir 'upload.jks'
$alias = 'upload'

$keytool = @(
  (Join-Path $env:JAVA_HOME 'bin\keytool.exe'),
  'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $keytool) { throw 'keytool not found. Install Android Studio or set JAVA_HOME.' }

New-Item -ItemType Directory -Force $dir | Out-Null
if (Test-Path $keystore) {
  Write-Host "An upload key already exists at $keystore. Not replacing it."
} else {
  & $keytool -genkeypair -v -keystore $keystore -alias $alias -keyalg RSA -keysize 2048 -validity 10000 `
    -storetype PKCS12 -dname 'CN=Thumb Party, O=Thumb Party, C=US'
  if ($LASTEXITCODE -ne 0) { throw 'keytool failed.' }
}

$secure = Read-Host 'Type the keystore password again (for key.properties)' -AsSecureString
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

# PKCS12 keystores use the same password for the key.
$props = Join-Path $dir 'key.properties'
@(
  "storeFile=$($keystore -replace '\\', '/')",
  "storePassword=$password",
  "keyAlias=$alias",
  "keyPassword=$password"
) | Set-Content -Encoding ascii $props
Write-Host "Wrote $props"

# Local release builds pick it up through this variable (see android/app/build.gradle.kts).
[Environment]::SetEnvironmentVariable('THUMBPARTY_KEY_PROPERTIES', $props, 'User')
Write-Host 'Set THUMBPARTY_KEY_PROPERTIES for your user (new terminals see it).'

$b64 = Join-Path $dir 'upload.jks.base64'
[Convert]::ToBase64String([IO.File]::ReadAllBytes($keystore)) | Set-Content -Encoding ascii $b64

Write-Host ''
Write-Host 'Now add the GitHub secrets for the release workflow (run from the repository folder):'
Write-Host "  Get-Content '$b64' | gh secret set ANDROID_KEYSTORE_BASE64"
Write-Host '  gh secret set ANDROID_KEYSTORE_PASSWORD   (paste the password when asked)'
Write-Host "  gh secret set ANDROID_KEY_ALIAS --body $alias"
Write-Host '  gh secret set ANDROID_KEY_PASSWORD        (the same password)'
