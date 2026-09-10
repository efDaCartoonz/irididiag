# iRidi Diagnostics Scripts

A collection of standalone tools for diagnosing iRidi servers, storage, and
cloud connectivity. The Linux scripts use portable POSIX `sh` and support
BusyBox-based HS Server firmware. The Windows scripts support the built-in
Windows PowerShell versions found on Windows 7, 10, and 11.

## Repository layout

- `scripts/linux` — Linux, Debian, and BusyBox-based firmware;
- `scripts/windows` — Windows 7, Windows 10, and Windows 11.

### Linux and BusyBox

| File | Purpose |
| --- | --- |
| `check_i3knx.sh` | Application-level checks for i3 KNX cloud resources and an active Cloud Gate session |
| `check_bus77_home.sh` | Application-level checks for Bus77 Home cloud resources |
| `check_bus77_lite.sh` | Application-level checks for Bus77 Lite cloud resources |
| `check_iridi_pro_ru.sh` | iRidi Pro Cloud checks for the RU region |
| `check_iridi_pro_eu.sh` | iRidi Pro Cloud checks for the EU region |
| `check_emmc_health.sh` | eMMC health, root write path, overlay, and kernel error diagnostics |
| `check_can_bus.sh` | CAN/Bus77 interface health, counters, gateway settings, and observed participants |
| `monitor_can_bus.sh` | Live passive CAN/Bus77 packet monitor with RX/TX and bus composition summaries |
| `scan_bus77_devices.sh` | Read-only active Bus77 discovery with model, HWID, firmware, and channel counts |

### Windows

| File | Purpose |
| --- | --- |
| `run_iridi_cloud_windows.cmd` | Double-click launcher with a product menu and automatic logging |
| `check_iridi_cloud_windows_10_11.ps1` | Cloud diagnostics for Windows 10/11 and Windows PowerShell 5.1 |
| `check_iridi_cloud_windows_7.ps1` | Cloud diagnostics for Windows 7 and Windows PowerShell 2.0 or newer |

## Result colors and exit codes

Interactive output uses the following status colors:

- green — `[OK]` and `RESULT: PASS`;
- yellow — `[ATTENTION]` and `RESULT: WARN`;
- red — `[NOT OK]` and `RESULT: FAIL`.

Linux colors are enabled only when output is connected to a terminal. Set
`NO_COLOR=1` to disable them. Log files remain plain text and never contain ANSI
color sequences.

Exit codes are consistent across the current tools:

- `0` — `PASS`: required checks passed;
- `1` — `WARN`: the main checks passed, but one or more items require attention;
- `2` — `FAIL`: a required check failed or the tool could not complete safely.

## Cloud diagnostics on Linux

The cloud checks do more than ping a host or open a port. Each script performs
DNS resolution and a real HTTP(S) GET request, reads the response payload, and
reports the actual IP address, documented IP address, HTTP status, content type,
payload size, request time, and retry count. Network failures without an HTTP
response are retried up to three times. A `403` response from protected storage
still confirms application-level reachability.

The terminal shows live progress while a separate log file is created for every
run. A typical file name is:

```text
cloud_bus77_home_SERVER_20260901_153000_1234.log
```

Download and run a script with `wget`:

```sh
cd /tmp
wget --no-check-certificate https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/linux/check_bus77_home.sh
sh check_bus77_home.sh
```

Run the other product profiles in the same way:

```sh
sh check_i3knx.sh
sh check_bus77_lite.sh
sh check_iridi_pro_ru.sh
sh check_iridi_pro_eu.sh
```

Cloud Gate is evaluated from an active `iridium` process session on the Linux
server. Run the matching product script on a server with that product active;
otherwise, a detected session may belong to different software.

## CAN/Bus77 diagnostics on HSS and ProAV

The check and monitor tools are passive: they never send CAN frames and never change the
interface configuration. By default, they automatically detect and inspect all
SocketCAN interfaces, including both channels on platforms that provide `can0`
and `can1`.

Download and run the short diagnostic:

```sh
cd /tmp
wget --no-check-certificate https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/linux/check_can_bus.sh
sh check_can_bus.sh
```

The diagnostic reports the controller state, bitrate, driver, carrier, CAN
error-state history, packet and error counter changes, active iRidi Server data
directory, CAN gateway settings, gateway listeners, and observed RX participant
signatures. Its default passive sample lasts 15 seconds.

Download and run the live monitor:

```sh
cd /tmp
wget --no-check-certificate https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/linux/monitor_can_bus.sh
sh monitor_can_bus.sh
```

The monitor displays each packet with its interface, RX/TX direction, CAN ID,
length, and payload. After 60 seconds it prints kernel counter changes and a
summary of observed RX and TX participant signatures.

Optional parameters can select one channel or change the observation time:

```sh
sh check_can_bus.sh --interface can0 --duration 30
sh monitor_can_bus.sh --interface can1 --duration 300
```

Passive reports decode the 16-bit CAN device ID from Extended ID bits 28..13 and
source LID candidates from apparent Bus77 packet headers, without CRC validation.
Use the active scanner to verify device identities. Silent devices are not visible and
their model or full HWID is not requested.

To request a read-only Bus77 inventory, download and run the active scanner:

```sh
cd /tmp
wget --no-check-certificate https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/linux/scan_bus77_devices.sh
sh scan_bus77_devices.sh
```

The scanner sends one System Search request and one Device Info request per
discovered LID. It validates CRC16 and reports device name, producer, model,
full HWID, CAN device ID, firmware ID and version, and channel/tag counts. It
does not send address assignment, identification LED, channel control, or
firmware commands.

Run only one scanner at a time. It uses CAN ID `0xFFFE` and LID `254` and stops
if this identity is observed in its initial sample. Silent address conflicts
cannot be ruled out. The default interface is `can0`; use `--interface can1`
to select another channel and `--timeout 10` for a longer response window.
Only responding devices are listed; an incomplete profile produces `WARN`.
Responses are reassembled, CRC-checked and matched to the discovered CAN ID,
LID and HWID, including devices that omit the optional transaction ID.
Protocol reference: [official BUS77 SDK](https://github.com/iRidium-Mobile/BUS77-SDK).

## Cloud diagnostics on Windows

1. Download the [repository ZIP archive](https://github.com/efDaCartoonz/irididiag/archive/refs/heads/main.zip).
2. Extract the entire archive.
3. Open `scripts\windows`.
4. Double-click `run_iridi_cloud_windows.cmd`.
5. Select i3 KNX, Bus77 Home, Bus77 Lite, iRidi Pro RU, or iRidi Pro EU.

The launcher detects the installed Windows PowerShell version, selects the
compatible diagnostic engine, displays live progress, and keeps the window open
after completion. Each run is saved under `scripts\windows\logs` with the
product, region, and timestamp in the file name.

Windows 10/11 can also run the PowerShell script directly:

```powershell
Set-Location $env:TEMP
curl.exe -fL "https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/windows/check_iridi_cloud_windows_10_11.ps1" -o "check_iridi_cloud_windows_10_11.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\check_iridi_cloud_windows_10_11.ps1 -Product bus77-home
```

Supported parameters:

```powershell
-Product i3knx
-Product bus77-home
-Product bus77-lite
-Product iridi-pro -Region RU
-Product iridi-pro -Region EU
```

Windows 7 can run its compatible script directly:

```bat
certutil.exe -urlcache -split -f "https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/windows/check_iridi_cloud_windows_7.ps1" "%TEMP%\check_iridi_cloud_windows_7.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\check_iridi_cloud_windows_7.ps1" -Product bus77-home
```

The Windows 7 version uses the built-in WinHTTP component and explicitly enables
TLS 1.2. If the operating system does not provide TLS 1.2 support, the script
reports a connection error so it can be distinguished from a cloud service
response.

## eMMC diagnostics

Run the full diagnostic as `root`:

```sh
sh check_emmc_health.sh
```

Download the current version with `wget`:

```sh
cd /tmp
wget --no-check-certificate https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/linux/check_emmc_health.sh
sh check_emmc_health.sh
```

The script reports the eMMC model, manufacturer, `LIFE_TIME`, `PRE_EOL_INFO`,
`USER_WP`, block-device read-only state, root filesystem, relevant kernel errors,
and the complete root write path. On overlay systems it also reports the
`upperdir`, `workdir`, backing filesystem, mount mode, free space, and inode use.

By default, it creates a temporary 1 MiB file directly under `/`, runs `sync`,
reads the file twice, compares checksums, and removes the file. This verifies the
actual write path through the root filesystem or overlay. Use the read-only mode
to collect passive information without creating the test file:

```sh
sh check_emmc_health.sh --no-write
```

The script never writes directly to the block device, runs `fsck`, or remounts a
filesystem. A `PASS` result confirms the checks performed during that run; it
does not rule out intermittent faults or replace a full-device endurance test.

Every run creates a plain-text log such as:

```text
emmc_diagnostic_SERVER_20260901_153000_1234.log
```
