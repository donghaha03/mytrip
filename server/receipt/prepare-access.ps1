param([switch]$Copy)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Security
$taskCodeDir = Join-Path $env:LOCALAPPDATA 'mytrip-receipt'
$taskCodePath = Join-Path $taskCodeDir 'gemini-access.dpapi'
if (Test-Path -LiteralPath $taskCodePath) {
  $taskCode = [Text.Encoding]::UTF8.GetString([Security.Cryptography.ProtectedData]::Unprotect(
    [IO.File]::ReadAllBytes($taskCodePath), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
} else {
  if ($Copy) { throw 'Run preparation before copying the code.' }
  $taskBytes = New-Object byte[] 32
  $taskRandom = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $taskRandom.GetBytes($taskBytes) } finally { $taskRandom.Dispose() }
  $taskCode = 'mytrip_' + [Convert]::ToBase64String($taskBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
  New-Item -ItemType Directory -Path $taskCodeDir -Force | Out-Null
  [IO.File]::WriteAllBytes($taskCodePath, [Security.Cryptography.ProtectedData]::Protect(
    [Text.Encoding]::UTF8.GetBytes($taskCode), $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
}
if ($Copy) {
  # Explicit user action only; the agent does not print or copy the private code.
  Set-Clipboard -Value $taskCode
  Write-Output 'Server access code copied. It is not a Gemini API key.'
} else {
  Push-Location $PSScriptRoot
  try {
    $env:WRANGLER_SEND_METRICS = 'false'
    $taskCode | & npx --yes wrangler@4.147.0 secret put RECEIPT_ACCESS_CODE
    if ($LASTEXITCODE -ne 0) { throw 'Cloudflare access code setup failed; the same code is retained for retry.' }
  } finally { Pop-Location }
}
$taskCode = $null
