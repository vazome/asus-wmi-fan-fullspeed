# FanToggle - tray icon that toggles the ASUS CPU fan (0x00110013) between
# full speed (DEVS 1) and BIOS auto control (DEVS 0) via ATK WMI.
# Left-click the icon to toggle. Right-click for Full speed / Auto / Exit.
# Hover to see current CPU (and GPU, if present) RPM. Exiting puts the fan back on Auto.

$DeviceId    = 0x00110013   # CPU fan control (full speed / auto)
$GpuFanId    = 0x00110014   # GPU fan - read-only here (DEVS is ignored on UX8402VV)

# --- Self-elevate if not admin -------------------------------------------------
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    exit
}

# --- Single instance -----------------------------------------------------------
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\FanToggleTray', [ref]$created)
if (-not $created) { exit }

# --- DPI awareness -------------------------------------------------------------
# powershell.exe isn't DPI-aware, so Windows bitmap-stretches its UI (blurry menu
# and icon on scaled displays). Opt in to per-monitor v2 before any UI is created.
Add-Type -Namespace Win32 -Name Dpi -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
'@
if (-not [Win32.Dpi]::SetProcessDpiAwarenessContext([IntPtr]-4)) { [void][Win32.Dpi]::SetProcessDPIAware() }

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$wmi = Get-WmiObject -Namespace 'root\wmi' -Class 'AsusAtkWmi_WMNB'

function Get-FanRpm([uint32]$id) {
    # DSTS low 16 bits = fan speed in units of 100 RPM (e.g. 0x10038 -> 56 -> 5600).
    # $null if the device isn't present (presence bit 0x10000 clear).
    try {
        $s = $wmi.DSTS($id).device_status
        if (-not ($s -band 0x10000)) { return $null }
        return ($s -band 0xFFFF) * 100
    } catch { return $null }
}

function Set-FullSpeed([bool]$full) {
    $wmi.DEVS($DeviceId, [uint32]$full) | Out-Null
    $script:full = $full
    Update-Icon
}

function New-DotIcon([System.Drawing.Color]$color) {
    # Draw at the tray's actual pixel size (16 px at 100 %, 24 at 150 %, ...) so it isn't resampled.
    $sz  = [System.Windows.Forms.SystemInformation]::SmallIconSize.Width
    $pad = [math]::Max(1, [int]($sz / 8))
    $d   = $sz - 2 * $pad - 1
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), ([float][math]::Max(1.0, $sz / 16.0))
    $bmp = New-Object System.Drawing.Bitmap $sz, $sz
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $color), $pad, $pad, $d, $d)
    $g.DrawEllipse($pen, $pad, $pad, $d, $d)
    $g.Dispose()
    [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$iconFull = New-DotIcon ([System.Drawing.Color]::FromArgb(40, 180, 80))
$iconAuto = New-DotIcon ([System.Drawing.Color]::FromArgb(120, 120, 120))

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Visible = $true

function Update-Icon {
    $cpu  = Get-FanRpm $DeviceId
    $gpu  = Get-FanRpm $GpuFanId
    $rpmS = if ($null -eq $cpu) { '' }
            elseif ($null -eq $gpu) { " - $cpu RPM" }
            else { " - CPU $cpu / GPU $gpu RPM" }
    $icon = if ($script:full) { $iconFull } else { $iconAuto }
    if ($tray.Icon -ne $icon) { $tray.Icon = $icon }
    $tray.Text = if ($script:full) { "Fan: FULL SPEED$rpmS" } else { "Fan: AUTO$rpmS" }
    $miFull.Checked = $script:full
    $miAuto.Checked = -not $script:full
}

# Native Win32 menu (WinForms ContextMenu, not ContextMenuStrip) so Windows 11
# draws it with the system style - rounded, themed, crisp - like PowerToys' menus.
# ContextMenu/MenuItem exist in .NET Framework, i.e. Windows PowerShell 5.1.
$miFull = New-Object System.Windows.Forms.MenuItem 'Full speed', { Set-FullSpeed $true }
$miAuto = New-Object System.Windows.Forms.MenuItem 'Auto',       { Set-FullSpeed $false }
$miExit = New-Object System.Windows.Forms.MenuItem 'Exit (back to Auto)', {
    Set-FullSpeed $false
    $tray.Visible = $false
    [System.Windows.Forms.Application]::Exit()
}
$tray.ContextMenu = New-Object System.Windows.Forms.ContextMenu (,[System.Windows.Forms.MenuItem[]]@(
    $miFull, $miAuto, (New-Object System.Windows.Forms.MenuItem '-'), $miExit))

# The BIOS doesn't report the mode, so start from a known state: Auto.
Set-FullSpeed $false

# Poll RPM every 1 s. While in full speed, re-send DEVS 1 every 5 s: the firmware
# can silently drop back to auto (sleep/resume, power mode change) and there's no
# way to read the mode back, only the RPM.
$script:tick = 0
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.add_Tick({
    $script:tick++
    if ($script:full -and ($script:tick % 5 -eq 0)) {
        try { $wmi.DEVS($DeviceId, 1) | Out-Null } catch {}
    }
    Update-Icon
})
$timer.Start()

$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Set-FullSpeed (-not $script:full) }
})

[System.Windows.Forms.Application]::Run()
$timer.Stop()
$tray.Dispose()
$mutex.ReleaseMutex()
