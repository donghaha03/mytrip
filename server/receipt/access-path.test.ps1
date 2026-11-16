# Test only path selection: never decrypt, copy, generate or upload a code.
$ErrorActionPreference = 'Stop'
$taskSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'prepare-access.ps1') -Raw
$taskTokens = $null
$taskParseErrors = $null
[Management.Automation.Language.Parser]::ParseInput($taskSource, [ref]$taskTokens, [ref]$taskParseErrors) | Out-Null
if ($taskParseErrors.Count) { throw 'Invalid PowerShell syntax.' }
$taskBoundary = $taskSource.IndexOf('if (Test-Path -LiteralPath $taskCodePath) {')
if ($taskBoundary -lt 0) { throw 'Path-selection boundary not found.' }
$taskSelector = $taskSource.Substring(0, $taskBoundary)
$taskNormalPath = Join-Path $env:LOCALAPPDATA 'mytrip-receipt\gemini-access.dpapi'
$taskCachedPath = Join-Path $env:LOCALAPPDATA 'Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\mytrip-receipt\gemini-access.dpapi'
function Test-Path {
  param([string]$LiteralPath)
  if ($LiteralPath -eq $taskNormalPath) { return $taskNormalExists }
  if ($LiteralPath -eq $taskCachedPath) { return $taskCacheExists }
  throw 'Unexpected path lookup.'
}
foreach ($taskCase in @(
  @{ Normal = $true; Cache = $true; Expected = $taskNormalPath },
  @{ Normal = $false; Cache = $true; Expected = $taskCachedPath },
  @{ Normal = $false; Cache = $false; Expected = $taskNormalPath }
)) {
  $taskNormalExists = $taskCase.Normal
  $taskCacheExists = $taskCase.Cache
  Invoke-Expression $taskSelector
  if ($taskCodePath -ne $taskCase.Expected) { throw 'Wrong access code path selected.' }
}
Write-Output 'Access code path checks passed: normal file, Codex cache, missing file. No secrets accessed.'
