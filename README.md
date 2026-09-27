# FanToggle

A tiny Windows tray app that switches an ASUS laptop's CPU fan between **full speed** and **Auto** (BIOS control) with one click — no admin PowerShell needed each time.

It calls the ASUS ATK WMI interface (`root\wmi` → `AsusAtkWmi_WMNB`) on device `0x00110013` (CPU fan control):

| Call | Effect |
|---|---|
| `DEVS(0x00110013, 1)` | Fan to full speed |
| `DEVS(0x00110013, 0)` | Back to Auto |
| `DSTS(0x00110013)` | Low 16 bits = fan speed in units of 100 RPM |

## Usage

- **Left-click** the tray dot to toggle — green = full speed, grey = Auto.
- **Hover** to see the current RPM (refreshes every 3 s).
- **Right-click** for Full speed / Auto / Exit. Exiting returns the fan to Auto.
- The app always starts in Auto, since the BIOS doesn't report the current mode.

## Install

From an **admin** PowerShell, in this folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install.ps1
```

This registers a `FanToggle` scheduled task that starts the app elevated at logon (no UAC prompt), adds a **Fan Toggle** desktop shortcut, and starts it right away. The task points at wherever this folder is, so re-run `Install.ps1` if you move it.

To run once without installing, right-click `FanToggle.ps1` → **Run with PowerShell** (it will ask for admin).

## Uninstall

From an admin PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

## Compatibility

Tested on an ASUS laptop exposing `AsusAtkWmi_WMNB`. Other models may use different device IDs — check with:

```powershell
$w = Get-WmiObject -Namespace root\wmi -Class AsusAtkWmi_WMNB
$w.DSTS(0x00110013).device_status
```

A value with bit `0x10000` set means the device is present.
