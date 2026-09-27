# asus-wmi-fan-fullspeed

A tiny Windows tray app that switches an ASUS laptop's **CPU fan** between **full speed** and **Auto** (BIOS control) with one click, instead of running WMI calls from an admin PowerShell every time.

It talks to the ASUS ATK WMI interface (`root\wmi` → `AsusAtkWmi_WMNB`) on device `0x00110013`, the CPU fan control device introduced in ASUS WMI spec 8.3:

| Call | Effect |
|---|---|
| `DEVS(0x00110013, 1)` | CPU fan to full speed |
| `DEVS(0x00110013, 0)` | CPU fan back to Auto |
| `DSTS(0x00110013)` | Bit `0x10000` = device present; low 16 bits = fan speed in units of 100 RPM |

These semantics match the Linux kernel's `asus-wmi` driver (`ASUS_WMI_DEVID_CPU_FAN_CTRL`, `FAN_TYPE_SPEC83`).

## Scope

**This is a fan-only override.** It is not ASUS's own "Full Speed" performance mode (MyASUS / ProArt Creator Hub / Armoury Crate). That mode is a thermal policy — `0x00110019` value `3` on Zenbook/Vivobook/ProArt, `0x00120075` on ROG/TUF — which also raises power limits. This tool leaves the performance mode and TDP untouched and only pins the CPU fan at maximum.

**Works on:** ASUS laptops whose firmware exposes `0x00110013` (presence bit set). This is common on recent ROG, TUF, Zenbook, Vivobook and ProArt models, but it's per-model — check below. Older models that only have the legacy AGFN fan interface are not supported.

**Only the CPU fan is controlled.** Some models also expose a GPU fan (`0x00110014`) and a middle fan (`0x00110031`). The tray tooltip shows the GPU fan's RPM when present, but the app doesn't write to it.

### Tested

| Model | CPU fan `0x00110013` | GPU fan `0x00110014` | Middle fan | Perf. mode device |
|---|---|---|---|---|
| Zenbook Pro 14 Duo OLED (UX8402VV) | ✅ full speed ~9,800 RPM, Auto returns to ~5,600 | Readable; `DEVS` ignored (no speed change after 20 s) | Not present | `0x00110019` |

### Check your laptop

In an admin PowerShell:

```powershell
$w = Get-WmiObject -Namespace root\wmi -Class AsusAtkWmi_WMNB
0x00110013,0x00110014,0x00110031,0x00110019,0x00120075 |
    % { '{0:X8} -> {1:X8}' -f $_, $w.DSTS($_).device_status }
```

`0x00110013` must return a value with bit `0x10000` set (e.g. `00010038`). `FFFFFFFE` means the device isn't supported.

## Usage

- **Left-click** the tray dot to toggle — green = full speed, grey = Auto.
- **Hover** to see current fan RPM (refreshes every 3 s).
- **Right-click** for Full speed / Auto / Exit. Exiting returns the fan to Auto.
- The app always starts in Auto, since the firmware doesn't report the current fan mode.

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

## References

- Linux kernel [`asus-wmi.h`](https://github.com/torvalds/linux/blob/master/include/linux/platform_data/x86/asus-wmi.h) / [`asus-wmi.c`](https://github.com/torvalds/linux/blob/master/drivers/platform/x86/asus-wmi.c)
- [G-Helper](https://github.com/seerge/g-helper) — `AsusACPI.cs` device IDs; [issue #2589](https://github.com/seerge/g-helper/issues/2589) on UX8402VV Full Speed mode
