# 배포용 웹 빌드.
#
#   . C:\Users\dongb\dev\flutter-env.ps1
#   .\tool\build_for_web.ps1
#
# flutter build web 결과를 그대로 올리면 두 가지가 문제라서 후처리한다:
#
#  1. index.html 의 <base href="/"> — 루트가 아닌 하위 경로(예: /artifact/<id>)에
#     배포하면 모든 에셋 경로가 깨진다. 지우면 문서 URL 기준 상대경로로 풀린다.
#     루트 도메인에 올릴 거면 -KeepBaseHref 를 주면 된다.
#  2. canvaskit/*.symbols — 런타임에 안 쓰는 디버그 심볼. 6MB 넘게 차지한다.
#
# --no-web-resources-cdn: canvaskit 을 gstatic CDN 대신 번들에 넣는다.
# 외부 스크립트를 막는 호스팅(Artifact 등)에서도 뜨게 하려면 필요하다.

param([switch]$KeepBaseHref)

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

flutter build web --release --no-wasm-dry-run --no-web-resources-cdn
if ($LASTEXITCODE -ne 0) { throw "flutter build web 실패" }

Get-ChildItem build\web -Recurse -File -Include *.symbols | Remove-Item -Force
Remove-Item build\web\.last_build_id -Force -ErrorAction SilentlyContinue

if (-not $KeepBaseHref) {
  $index = 'build\web\index.html'
  $html = [IO.File]::ReadAllText($index)
  $html = $html -replace '(?s)<!--\s*If you are serving your web app.*?-->\s*\r?\n\s*<base href="/">\r?\n', ''
  [IO.File]::WriteAllText($index, $html, (New-Object Text.UTF8Encoding $false))
  if ($html -match '<base') { Write-Warning 'base href 가 아직 남아 있다 — index.html 확인 필요' }
}

$f = Get-ChildItem build\web -Recurse -File
'{0} files, {1:N1} MB -> build\web' -f $f.Count, (($f | Measure-Object Length -Sum).Sum / 1MB)
