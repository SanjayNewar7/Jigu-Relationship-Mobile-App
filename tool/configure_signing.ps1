$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$target = Join-Path $projectRoot 'android\key.properties'
$storePath = Read-Host 'Keystore path (Enter for upload-keystore.jks in this project)'
if ([string]::IsNullOrWhiteSpace($storePath)) { $storePath = Join-Path $projectRoot 'upload-keystore.jks' }
$storePath = (Resolve-Path -LiteralPath $storePath).Path
$alias = Read-Host 'Key alias (Enter for upload)'
if ([string]::IsNullOrWhiteSpace($alias)) { $alias = 'upload' }
$storeSecret = Read-Host 'Keystore password (hidden)' -AsSecureString
$keySecret = Read-Host 'Key password (hidden; Enter to use keystore password)' -AsSecureString
function Plain([Security.SecureString]$value) {
 $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($value)
 try { [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
 finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }
}
function EscapeProperty([string]$value) {
 $value.Replace('\','\\').Replace(':','\:').Replace('=','\=').Replace('#','\#').Replace('!','\!').Replace(' ','\ ')
}
try {
 $storePass = Plain $storeSecret
 $keyPass = Plain $keySecret
 if ([string]::IsNullOrEmpty($keyPass)) { $keyPass = $storePass }
 $body = @("storeFile=$(EscapeProperty $storePath)","keyAlias=$(EscapeProperty $alias)","storePassword=$(EscapeProperty $storePass)","keyPassword=$(EscapeProperty $keyPass)") -join [Environment]::NewLine
 [IO.File]::WriteAllText($target, $body, [Text.UTF8Encoding]::new($false))
 Write-Host 'Signing configuration saved locally. Passwords were not printed.'
} finally {
 $storePass = $null; $keyPass = $null; $body = $null
 $storeSecret.Dispose(); $keySecret.Dispose()
}
