# Adds the Nudge widget to the emulator home screen (answers the system "add
# widget" dialog), then presses the tick button of the first row.
# Pair with: flutter test integration_test/e2e_widget_test.dart --dart-define=NUDGE_E2E=true
param([string]$Serial = 'emulator-5554')

$adb = 'D:\program\Android SDK\platform-tools\adb.exe'
$dump = Join-Path $env:TEMP 'nudge_widget_ui.xml'

function Get-Nodes {
  & $adb -s $Serial shell uiautomator dump /sdcard/nudge_widget_ui.xml | Out-Null
  & $adb -s $Serial pull /sdcard/nudge_widget_ui.xml $dump | Out-Null
  if (-not (Test-Path $dump)) { return @() }
  [xml]$x = Get-Content $dump -Raw
  return @($x.SelectNodes('//node'))
}

function Center($node) {
  if ($node.bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
    return @{ X = [int](([int]$Matches[1] + [int]$Matches[3]) / 2); Y = [int](([int]$Matches[2] + [int]$Matches[4]) / 2) }
  }
}

function Find-Node([scriptblock]$pred) {
  Get-Nodes | Where-Object $pred | Select-Object -First 1
}

# 1. Wait for the pin dialog and accept it.
$added = $false
for ($i = 0; $i -lt 60 -and -not $added; $i++) {
  Start-Sleep -Seconds 2
  & $adb -s $Serial shell pm grant com.bayu.nudge android.permission.POST_NOTIFICATIONS 2>&1 | Out-Null
  $btn = Find-Node { ($_.text -match '^(Add|Add to home screen|Tambah|Tambahkan)') }
  if ($btn) {
    $c = Center $btn
    & $adb -s $Serial shell input tap $c.X $c.Y | Out-Null
    Write-Host "pressed '$($btn.text)' at $($c.X),$($c.Y)"
    $added = $true
  }
}
if (-not $added) { Write-Host 'pin dialog never appeared'; exit 1 }

# 2. Go home and find the widget.
Start-Sleep -Seconds 3
& $adb -s $Serial shell input keyevent KEYCODE_HOME | Out-Null
Start-Sleep -Seconds 3
$tick = $null
for ($i = 0; $i -lt 15 -and -not $tick; $i++) {
  $nodes = Get-Nodes
  $header = $nodes | Where-Object { $_.text -like 'Nudge*belum selesai*' } | Select-Object -First 1
  if ($header) { Write-Host "widget header: $($header.text)" }
  $tick = $nodes | Where-Object { $_.'content-desc' -eq 'Selesai' } | Select-Object -First 1
  if (-not $tick) { Start-Sleep -Seconds 2 }
}
if (-not $tick) { Write-Host 'widget tick button not found'; exit 1 }
$c = Center $tick
& $adb -s $Serial shell input tap $c.X $c.Y | Out-Null
Write-Host "pressed widget tick at $($c.X),$($c.Y)"
Start-Sleep -Seconds 5
Write-Host 'driver done'
