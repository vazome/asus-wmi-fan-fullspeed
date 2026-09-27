# One-time setup (run as admin): registers a scheduled task that starts FanToggle
# elevated at logon with no UAC prompt, plus a desktop shortcut to start it manually.

$script = Join-Path $PSScriptRoot 'FanToggle.ps1'
$arg    = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""

$action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0

Register-ScheduledTask -TaskName 'FanToggle' -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

# Desktop shortcut that launches the task (elevated, no UAC)
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Fan Toggle.lnk'
$sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$sc.TargetPath = 'schtasks.exe'
$sc.Arguments  = '/run /tn FanToggle'
$sc.WindowStyle = 7
$sc.IconLocation = 'shell32.dll,12'
$sc.Save()

Start-ScheduledTask -TaskName 'FanToggle'
Write-Host 'Installed. FanToggle is running in the tray and will start at logon.'
