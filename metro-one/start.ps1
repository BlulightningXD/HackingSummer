$ErrorActionPreference = 'Stop'
$secret = Read-Host 'kPCbkdz4Wvi3yxw7fKlsu1RTYmpi3wj0' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
try {
  $env:OTD_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
  node (Join-Path $PSScriptRoot 'server.js')
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
  Remove-Variable secret, pointer -ErrorAction SilentlyContinue
  Remove-Item Env:OTD_API_KEY -ErrorAction SilentlyContinue
}
