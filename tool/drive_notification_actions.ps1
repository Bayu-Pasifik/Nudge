# Drives the notification shade on an emulator: presses "Tunda 10 mnt" on the
# first Nudge notification, then "Selesai" on the next one.
# Usage: powershell -File tool/drive_notification_actions.ps1 [-Serial emulator-5554]
param(
  [string]$Serial = 'emulator-5554',
  # Button labels to press in order (waits 8s between presses).
  [string[]]$Steps = @('Tunda 10', 'Selesai'),
  # Print the notification flags of a notification title before pressing.
  [string]$ShowFlagsFor = ''
)

$adb = 'D:\program\Android SDK\platform-tools\adb.exe'
$dump = Join-Path $env:TEMP 'nudge_ui.xml'

# Center of the clickable node whose label contains $text, or $null.
function Find-Button([string]$text) {
  & $adb -s $Serial shell uiautomator dump /sdcard/nudge_ui.xml | Out-Null
  & $adb -s $Serial pull /sdcard/nudge_ui.xml $dump | Out-Null
  if (-not (Test-Path $dump)) { return $null }
  [xml]$xml = Get-Content $dump -Raw
  $node = $xml.SelectNodes('//node') |
    Where-Object { $_.clickable -eq 'true' -and ($_.text -like "*$text*" -or $_.'content-desc' -like "*$text*") } |
    Select-Object -First 1
  if (-not $node) { return $null }
  if ($node.bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
    return @{ X = [int](([int]$Matches[1] + [int]$Matches[3]) / 2); Y = [int](([int]$Matches[2] + [int]$Matches[4]) / 2) }
  }
  return $null
}

function Press-Action([string]$text, [int]$timeoutSec = 120) {
  $end = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $end) {
    # `flutter test` may reinstall the app (revoking the permission): re-grant.
    & $adb -s $Serial shell pm grant com.bayu.nudge android.permission.POST_NOTIFICATIONS 2>&1 | Out-Null
    & $adb -s $Serial shell cmd statusbar expand-notifications | Out-Null
    Start-Sleep -Seconds 2
    # Layout animates while the shade opens: only tap once two dumps agree.
    $a = Find-Button $text
    if (-not $a) {
      # Low-priority notifications (sticky notes) are collapsed: expand first.
      $e = Find-Button 'Expand'
      if ($e) {
        & $adb -s $Serial shell input tap $e.X $e.Y | Out-Null
        Start-Sleep -Seconds 1
        $a = Find-Button $text
      }
    }
    Start-Sleep -Milliseconds 700
    $b = Find-Button $text
    if ($a -and $b -and $a.X -eq $b.X -and $a.Y -eq $b.Y) {
      & $adb -s $Serial shell input tap $b.X $b.Y | Out-Null
      Write-Host "pressed '$text' at $($b.X),$($b.Y)"
      Start-Sleep -Seconds 2
      & $adb -s $Serial shell cmd statusbar collapse | Out-Null
      return $true
    }
    & $adb -s $Serial shell cmd statusbar collapse | Out-Null
    Start-Sleep -Seconds 2
  }
  Write-Host "never found '$text'"
  return $false
}

foreach ($step in $Steps) {
  if ($ShowFlagsFor) {
    Start-Sleep -Seconds 12
    $rec = & $adb -s $Serial shell dumpsys notification --noredact | Select-String -Pattern "android.title=String \($ShowFlagsFor\)" -Context 30,0 | Select-Object -First 1
    $flags = $rec.Context.PreContext | Select-String 'flags=' | Select-Object -Last 1
    Write-Host "flags for '$ShowFlagsFor': $flags"
  }
  if (-not (Press-Action $step)) { exit 1 }
  Start-Sleep -Seconds 8
}
Write-Host 'driver done'
