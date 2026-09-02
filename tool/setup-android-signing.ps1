[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$propertiesPath = Join-Path $repositoryRoot 'android\key.properties'
$signingDirectory = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.kiboard\signing'
$keystorePath = Join-Path $signingDirectory 'upload-keystore.jks'
$certificateDirectory = Join-Path $repositoryRoot 'build\play'
$certificatePath = Join-Path $certificateDirectory 'upload_certificate.pem'
$keyAlias = 'kiboard-upload'

if ((Test-Path -LiteralPath $propertiesPath) -or (Test-Path -LiteralPath $keystorePath)) {
    throw 'Android signing already exists. Refusing to replace the upload key.'
}

$javaHome = $env:JAVA_HOME
if ([string]::IsNullOrWhiteSpace($javaHome)) {
    throw 'JAVA_HOME is required to locate keytool.'
}

$keytoolPath = Join-Path $javaHome 'bin\keytool.exe'
if (-not (Test-Path -LiteralPath $keytoolPath)) {
    throw "keytool was not found at $keytoolPath"
}

function New-SigningPassword {
    $bytes = [byte[]]::new(36)
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

$storePassword = New-SigningPassword
$keyPassword = New-SigningPassword

New-Item -ItemType Directory -Path $signingDirectory -Force | Out-Null
New-Item -ItemType Directory -Path $certificateDirectory -Force | Out-Null

try {
    & $keytoolPath -genkeypair -v `
        -keystore $keystorePath `
        -storetype JKS `
        -storepass $storePassword `
        -keypass $keyPassword `
        -alias $keyAlias `
        -keyalg RSA `
        -keysize 4096 `
        -validity 10000 `
        -dname 'CN=KiBoard Upload, OU=KiBoard, O=Maxia, L=Santiago, ST=Metropolitana, C=CL'
    if ($LASTEXITCODE -ne 0) {
        throw "keytool failed with exit code $LASTEXITCODE"
    }

    $portableKeystorePath = $keystorePath.Replace('\', '/')
    $properties = @(
        "storeFile=$portableKeystorePath"
        "storePassword=$storePassword"
        "keyAlias=$keyAlias"
        "keyPassword=$keyPassword"
    )
    [IO.File]::WriteAllLines(
        $propertiesPath,
        $properties,
        [Text.UTF8Encoding]::new($false)
    )

    & $keytoolPath -exportcert -rfc `
        -keystore $keystorePath `
        -storepass $storePassword `
        -alias $keyAlias `
        -file $certificatePath
    if ($LASTEXITCODE -ne 0) {
        throw "keytool certificate export failed with exit code $LASTEXITCODE"
    }
}
catch {
    Remove-Item -LiteralPath $propertiesPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $keystorePath -Force -ErrorAction SilentlyContinue
    throw
}

Write-Host 'Android upload signing is configured.'
Write-Host "Keystore: $keystorePath"
Write-Host "Public certificate: $certificatePath"
Write-Host 'Back up the keystore and android/key.properties in a secure password manager.'
