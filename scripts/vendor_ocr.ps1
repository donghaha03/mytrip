$ErrorActionPreference = 'Stop'
$taskOcrRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../web/ocr'))
$taskOcrTemp = New-Item -ItemType Directory -Path (Join-Path ([System.IO.Path]::GetTempPath()) ('mytrip-ocr-' + [guid]::NewGuid()))
New-Item -ItemType Directory -Force -Path $taskOcrRoot, (Join-Path $taskOcrRoot 'core'), (Join-Path $taskOcrRoot 'lang') | Out-Null
foreach ($taskPackage in @(@{name='tesseract.js'; version='6.0.1'}, @{name='tesseract.js-core'; version='6.1.2'})) {
  $taskMeta = Invoke-RestMethod ('https://registry.npmjs.org/' + $taskPackage.name + '/' + $taskPackage.version)
  $taskArchive = Join-Path $taskOcrTemp ($taskPackage.name + '.tgz')
  Invoke-WebRequest $taskMeta.dist.tarball -OutFile $taskArchive
  $taskActual = (Get-FileHash -Algorithm SHA1 -LiteralPath $taskArchive).Hash.ToLower()
  if ($taskActual -ne $taskMeta.dist.shasum) { throw 'npm artifact integrity mismatch' }
  $taskExtract = New-Item -ItemType Directory -Path (Join-Path $taskOcrTemp $taskPackage.name)
  tar -xf $taskArchive -C $taskExtract
  if ($LASTEXITCODE -ne 0) { throw 'Cannot unpack official npm package' }
  $taskPackageDir = Join-Path $taskExtract 'package'
  if ($taskPackage.name -eq 'tesseract.js') {
    Copy-Item -LiteralPath (Join-Path $taskPackageDir 'dist/tesseract.min.js'), (Join-Path $taskPackageDir 'dist/worker.min.js') -Destination $taskOcrRoot
    Copy-Item -LiteralPath (Join-Path $taskPackageDir 'LICENSE.md') -Destination (Join-Path $taskOcrRoot 'TESSERACT-LICENSE.txt')
    Get-ChildItem -LiteralPath (Join-Path $taskPackageDir 'dist') -Filter '*.LICENSE.txt' -File | Copy-Item -Destination $taskOcrRoot
  } else {
    Get-ChildItem -LiteralPath $taskPackageDir -File | Where-Object {$_.Name -match '^tesseract-core.*\.wasm(\.js)?$'} | Copy-Item -Destination (Join-Path $taskOcrRoot 'core')
    Copy-Item -LiteralPath (Join-Path $taskPackageDir 'LICENSE') -Destination (Join-Path $taskOcrRoot 'CORE-LICENSE.txt')
  }
}
foreach ($taskLanguage in @('eng', 'kor', 'jpn')) {
  Invoke-WebRequest ('https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/4.1.0/' + $taskLanguage + '.traineddata') -OutFile (Join-Path $taskOcrRoot ('lang/' + $taskLanguage + '.traineddata'))
}
Invoke-WebRequest 'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/4.1.0/LICENSE' -OutFile (Join-Path $taskOcrRoot 'DATA-LICENSE.txt')
Get-ChildItem -LiteralPath $taskOcrRoot -Recurse -File | Select-Object Name, Length
