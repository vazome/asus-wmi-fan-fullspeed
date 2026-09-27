# Run as admin: removes the scheduled task and desktop shortcut.
Unregister-ScheduledTask -TaskName 'FanToggle' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Fan Toggle.lnk') -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object CommandLine -like '*FanToggle.ps1*' |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Write-Host 'FanToggle removed.'
