Add-Type -AssemblyName System.Drawing
$taskReceiptDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../test/fixtures'))
New-Item -ItemType Directory -Force -Path $taskReceiptDir | Out-Null
$taskBitmap = New-Object System.Drawing.Bitmap 1000, 1400
$taskGraphics = [System.Drawing.Graphics]::FromImage($taskBitmap)
$taskGraphics.Clear([System.Drawing.Color]::White)
$taskFont = New-Object System.Drawing.Font 'Arial', 38
$taskY = 90
foreach ($taskLine in @('TEST CAFE', 'DATE 2026-10-04', '', 'Coffee            5,000', 'Sandwich          5,000', '', 'SUBTOTAL KRW 10,000', 'TAX KRW 1,000', '', 'TOTAL KRW 11,000', '', 'THANK YOU')) {
  $taskGraphics.DrawString($taskLine, $taskFont, [System.Drawing.Brushes]::Black, 70, $taskY)
  $taskY += 90
}
$taskBitmap.Save((Join-Path $taskReceiptDir 'receipt_en.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$taskGraphics.Clear([System.Drawing.Color]::White)
$taskBitmap.Save((Join-Path $taskReceiptDir 'receipt_blank.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$taskGraphics.Dispose(); $taskFont.Dispose(); $taskBitmap.Dispose()
$taskBitmap = New-Object System.Drawing.Bitmap 1600, 900
$taskGraphics = [System.Drawing.Graphics]::FromImage($taskBitmap)
$taskGraphics.Clear([System.Drawing.Color]::White)
$taskFont = New-Object System.Drawing.Font 'Malgun Gothic', 32
$taskY = 70
foreach ($taskLine in @('테스트 카페', 'DATE 2026-10-04', '상품명          단가     수량     금액', 'Americano      5,000      1       5,000', '공급가액 4,545원', '부가세 455원', '결제금액 KRW 5,000')) {
  $taskGraphics.DrawString($taskLine, $taskFont, [System.Drawing.Brushes]::Black, 90, $taskY)
  $taskY += 100
}
$taskBitmap.Save((Join-Path $taskReceiptDir 'receipt_landscape.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$taskGraphics.Dispose(); $taskFont.Dispose(); $taskBitmap.Dispose()
Get-ChildItem -LiteralPath $taskReceiptDir -File | Select-Object Name, Length
