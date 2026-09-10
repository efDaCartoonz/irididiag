#!/bin/sh

case "${1:-}" in
  -h|--help)
    printf 'Usage: sh %s [--interface can0|all] [--duration SECONDS] [--passive]\n' "${0##*/}"
    printf '%s\n' 'Default: read device identities, then observe the bus. --passive skips all requests.'
    exit 0
    ;;
esac

# Read device identities, then passively decode live CAN/Bus77 messages.
# --passive skips identity requests. Interface settings are never changed.
# Usage: sh monitor_can_bus.sh [--interface can0|all] [--duration 60]

if [ "${IRIDI_CAN_MONITOR_LOG_ACTIVE:-0}" != "1" ]; then
  CURRENT_DIRECTORY="$(pwd 2>/dev/null || printf '.')"
  LOG_DIRECTORY="${IRIDI_DIAG_LOG_DIR:-$CURRENT_DIRECTORY}"
  if [ ! -d "$LOG_DIRECTORY" ] || [ ! -w "$LOG_DIRECTORY" ]; then
    LOG_DIRECTORY="${TMPDIR:-/tmp}"
  fi
  HOST_LABEL="$(hostname 2>/dev/null || printf server)"
  HOST_LABEL="$(printf '%s' "$HOST_LABEL" | tr -c 'A-Za-z0-9._-' '_')"
  [ -n "$HOST_LABEL" ] || HOST_LABEL=server
  LOG_TIMESTAMP="$(date '+%Y%m%d_%H%M%S' 2>/dev/null || printf unknown_time)"
  LOG_FILE="$LOG_DIRECTORY/can_monitor_${HOST_LABEL}_${LOG_TIMESTAMP}_$$.log"
  export IRIDI_CAN_MONITOR_LOG_ACTIVE=1
  export IRIDI_CAN_MONITOR_LOG_FILE="$LOG_FILE"

  colorize_output() {
    awk '
      /\[OK\]|RESULT: PASS/ { printf "\033[32m%s\033[0m\n", $0; fflush(); next }
      /\[ATTENTION\]|RESULT: WARN/ { printf "\033[33m%s\033[0m\n", $0; fflush(); next }
      /\[NOT OK\]|RESULT: FAIL/ { printf "\033[31m%s\033[0m\n", $0; fflush(); next }
      / ERROR / { printf "\033[31m%s\033[0m\n", $0; fflush(); next }
      / RESPONSE / { printf "\033[32m%s\033[0m\n", $0; fflush(); next }
      / REQUEST / { printf "\033[36m%s\033[0m\n", $0; fflush(); next }
      { print; fflush() }
    '
  }

  if command -v tee >/dev/null 2>&1; then
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && command -v awk >/dev/null 2>&1; then
      sh "$0" "$@" 2>&1 | tee "$LOG_FILE" | colorize_output
    else
      sh "$0" "$@" 2>&1 | tee "$LOG_FILE"
    fi
    PIPELINE_RC=$?
    RESULT_LINE="$(grep '^RESULT:' "$LOG_FILE" 2>/dev/null | tail -n 1)"
    case "$RESULT_LINE" in
      *PASS*) FINAL_RC=0 ;;
      *WARN*) FINAL_RC=1 ;;
      *FAIL*) FINAL_RC=2 ;;
      *) FINAL_RC=2 ;;
    esac
    if [ "$PIPELINE_RC" -ne 0 ]; then
      FINAL_RC=2
      printf '[NOT OK] The log file could not be written completely.\n'
    fi
    printf '\nLog saved: %s\n' "$LOG_FILE" | tee -a "$LOG_FILE"
    exit "$FINAL_RC"
  fi

  sh "$0" "$@" >"$LOG_FILE" 2>&1
  FINAL_RC=$?
  cat "$LOG_FILE"
  printf '\nLog saved: %s\n' "$LOG_FILE"
  exit "$FINAL_RC"
fi

set +e
export LC_ALL=C

SCRIPT_VERSION=2.0
PASSIVE_ONLY=0
REQUESTED_INTERFACE=all
MONITOR_SECONDS=60
WARNINGS=0
FAILURES=0
WORK_DIR=""
CAPTURE_PID=""

separator() {
  printf '%s\n' '----------------------------------------------------------------'
}

ok() {
  printf '  [OK] %s\n' "$1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf '  [ATTENTION] %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf '  [NOT OK] %s\n' "$1"
}

usage() {
  printf '%s\n' 'Usage: sh monitor_can_bus.sh [--interface can0|all] [--duration SECONDS]'
  printf '%s\n' 'Defaults: read-only inventory, then a 60-second decoded passive monitor.'
  printf '%s\n' 'Use --passive to skip identity requests and display addresses without model names.'
}

# BEGIN GENERATED INVENTORY
run_bus77_inventory() (
  export IRIDI_BUS77_SCAN_LOG_ACTIVE=1

# Active read-only Bus77 discovery for iRidi HSS and ProAV servers.
# Sends only System Search (0x03) and Device Info (0x04) requests.
# Usage: sh scan_bus77_devices.sh [--interface can0] [--timeout 5]

case "${1:-}" in
  -h|--help)
    printf '%s\n' 'Usage: sh scan_bus77_devices.sh [--interface can0] [--timeout SECONDS]' 'Sends only read-only Bus77 Search and Device Info requests.'
    exit 0
    ;;
esac

if [ "${IRIDI_BUS77_SCAN_LOG_ACTIVE:-0}" != "1" ]; then
  CURRENT_DIRECTORY="$(pwd 2>/dev/null || printf '.')"
  LOG_DIRECTORY="${IRIDI_DIAG_LOG_DIR:-$CURRENT_DIRECTORY}"
  if [ ! -d "$LOG_DIRECTORY" ] || [ ! -w "$LOG_DIRECTORY" ]; then
    LOG_DIRECTORY="${TMPDIR:-/tmp}"
  fi
  HOST_LABEL="$(hostname 2>/dev/null || printf server)"
  HOST_LABEL="$(printf '%s' "$HOST_LABEL" | tr -c 'A-Za-z0-9._-' '_')"
  [ -n "$HOST_LABEL" ] || HOST_LABEL=server
  LOG_TIMESTAMP="$(date '+%Y%m%d_%H%M%S' 2>/dev/null || printf unknown_time)"
  LOG_FILE="$LOG_DIRECTORY/bus77_device_scan_${HOST_LABEL}_${LOG_TIMESTAMP}_$$.log"
  export IRIDI_BUS77_SCAN_LOG_ACTIVE=1
  export IRIDI_BUS77_SCAN_LOG_FILE="$LOG_FILE"

  colorize_output() {
    awk '
      /\[OK\]|RESULT: PASS/ { printf "\033[32m%s\033[0m\n", $0; fflush(); next }
      /\[ATTENTION\]|RESULT: WARN/ { printf "\033[33m%s\033[0m\n", $0; fflush(); next }
      /\[NOT OK\]|RESULT: FAIL/ { printf "\033[31m%s\033[0m\n", $0; fflush(); next }
      { print; fflush() }
    '
  }

  if command -v tee >/dev/null 2>&1; then
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && command -v awk >/dev/null 2>&1; then
      sh "$0" "$@" 2>&1 | tee "$LOG_FILE" | colorize_output
    else
      sh "$0" "$@" 2>&1 | tee "$LOG_FILE"
    fi
    PIPELINE_RC=$?
    RESULT_LINE="$(grep '^RESULT:' "$LOG_FILE" 2>/dev/null | tail -n 1)"
    case "$RESULT_LINE" in
      *PASS*) FINAL_RC=0 ;;
      *WARN*) FINAL_RC=1 ;;
      *) FINAL_RC=2 ;;
    esac
    if [ "$PIPELINE_RC" -ne 0 ]; then
      FINAL_RC=2
      printf '[NOT OK] The log file could not be written completely.\n'
    fi
    printf '\nLog saved: %s\n' "$LOG_FILE" | tee -a "$LOG_FILE"
    exit "$FINAL_RC"
  fi

  sh "$0" "$@" >"$LOG_FILE" 2>&1
  FINAL_RC=$?
  cat "$LOG_FILE"
  printf '\nLog saved: %s\n' "$LOG_FILE"
  exit "$FINAL_RC"
fi

set +e
export LC_ALL=C

SCRIPT_VERSION=1.1
CAN_INTERFACE=can0
RESPONSE_TIMEOUT=5
SCANNER_CAN_ID=65534
SCANNER_LID=254
WARNINGS=0
FAILURES=0
CAPTURE_PID=""
WORK_DIR=""

separator() {
  printf '%s\n' '----------------------------------------------------------------'
}

ok() {
  printf '  [OK] %s\n' "$1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf '  [ATTENTION] %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf '  [NOT OK] %s\n' "$1"
}

usage() {
  printf '%s\n' 'Usage: sh scan_bus77_devices.sh [--interface can0] [--timeout SECONDS]'
  printf '%s\n' 'Sends only read-only Bus77 Search and Device Info requests.'
}

cleanup() {
  if [ -n "$CAPTURE_PID" ]; then
    kill -INT "$CAPTURE_PID" 2>/dev/null
    wait "$CAPTURE_PID" 2>/dev/null
  fi
  [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

while [ "$#" -gt 0 ]; do
  case "$1" in
    --interface)
      shift
      CAN_INTERFACE="${1:-}"
      ;;
    --timeout)
      shift
      RESPONSE_TIMEOUT="${1:-}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '[NOT OK] Unknown argument: %s\n' "$1"
      usage
      printf 'RESULT: FAIL - NOT OK: invalid command-line arguments.\n'
      exit 2
      ;;
  esac
  shift
done

case "$CAN_INTERFACE" in
  ''|*[!A-Za-z0-9_.:-]*)
    printf '[NOT OK] Invalid interface name: %s\n' "$CAN_INTERFACE"
    printf 'RESULT: FAIL - NOT OK: invalid CAN interface name.\n'
    exit 2
    ;;
esac
case "$RESPONSE_TIMEOUT" in
  ''|*[!0-9]*)
    printf '[NOT OK] Timeout must be a whole number of seconds.\n'
    printf 'RESULT: FAIL - NOT OK: invalid timeout.\n'
    exit 2
    ;;
esac
if [ "$RESPONSE_TIMEOUT" -lt 2 ] || [ "$RESPONSE_TIMEOUT" -gt 30 ]; then
  printf '[NOT OK] Timeout must be between 2 and 30 seconds.\n'
  printf 'RESULT: FAIL - NOT OK: invalid timeout.\n'
  exit 2
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/iridi-bus77-scan.XXXXXX" 2>/dev/null)"
if [ -z "$WORK_DIR" ] || [ ! -d "$WORK_DIR" ]; then
  WORK_DIR="${TMPDIR:-/tmp}/iridi-bus77-scan.$$"
  mkdir -m 700 "$WORK_DIR" || { WORK_DIR=""; exit 2; }
fi
SEARCH_CAPTURE="$WORK_DIR/search.capture"
SEARCH_RESULTS="$WORK_DIR/search.results"
INFO_CAPTURE="$WORK_DIR/info.capture"
INFO_RESULTS="$WORK_DIR/info.results"
: >"$SEARCH_RESULTS"
: >"$INFO_RESULTS"

printf 'iRidi Bus77 Device Scanner\n'
printf 'Script version: %s\n' "$SCRIPT_VERSION"
printf 'Started: %s\n' "$(date 2>/dev/null || echo unknown)"
printf 'Device: %s | %s | %s\n' "$(hostname 2>/dev/null || echo unknown)" "$(uname -s 2>/dev/null)" "$(uname -m 2>/dev/null)"
printf 'Log file: %s\n' "${IRIDI_BUS77_SCAN_LOG_FILE:-not set}"
printf 'CAN interface: %s\n' "$CAN_INTERFACE"
printf 'Mode: active read-only discovery\n'
printf 'Allowed requests: System Search (0x03), Device Info (0x04)\n'
printf 'Scanner identity: CAN ID=0xFFFE, LID=254\n'

separator
printf '1. Safety and interface preflight\n'
if [ ! -d "/sys/class/net/$CAN_INTERFACE" ] || [ "$(cat "/sys/class/net/$CAN_INTERFACE/type" 2>/dev/null)" != "280" ]; then
  fail "$CAN_INTERFACE is not an available SocketCAN interface."
fi
for REQUIRED_COMMAND in ip awk candump cansend; do
  if ! command -v "$REQUIRED_COMMAND" >/dev/null 2>&1; then
    fail "$REQUIRED_COMMAND is required."
  fi
done
AWK_BITWISE="$(awk 'BEGIN { print xor(1, 2) ":" and(7, 3) ":" lshift(1, 4) ":" rshift(16, 2) }' 2>/dev/null)"
if [ "$AWK_BITWISE" != "3:3:16:4" ]; then
  fail 'The installed awk does not provide the required bitwise functions.'
fi

CAN_DETAILS="$(ip -details -statistics link show "$CAN_INTERFACE" 2>/dev/null)"
CAN_STATE="$(printf '%s\n' "$CAN_DETAILS" | awk '/can .* state / { for(i=1;i<=NF;i++) if($i=="state") {print $(i+1); exit} }')"
CAN_BITRATE="$(printf '%s\n' "$CAN_DETAILS" | awk '/ bitrate / { for(i=1;i<=NF;i++) if($i=="bitrate") {print $(i+1); exit} }')"
printf '  Controller state: %s\n' "${CAN_STATE:-not determined}"
printf '  Bitrate: %s bit/s\n' "${CAN_BITRATE:-not determined}"
case "$CAN_STATE" in
  ERROR-ACTIVE) ok "$CAN_INTERFACE is ready for discovery." ;;
  ERROR-WARNING|ERROR-PASSIVE) warn "$CAN_INTERFACE is $CAN_STATE; discovery will continue cautiously." ;;
  *) fail "$CAN_INTERFACE is not in an operational CAN state." ;;
esac

if [ "$FAILURES" -gt 0 ]; then
  separator
  printf 'RESULT: FAIL - NOT OK: safety preflight failed; no CAN frames were sent.\n'
  exit 2
fi

crc16_hex() {
  awk '
    BEGIN {
      crc = 65535
      for (i = 1; i < ARGC; i++) {
        byte = ARGV[i] + 0
        crc = xor(crc, byte)
        for (bit = 0; bit < 8; bit++) {
          if (and(crc, 1)) crc = xor(rshift(crc, 1), 40961)
          else crc = rshift(crc, 1)
        }
      }
      printf "%02X%02X", and(crc, 255), and(rshift(crc, 8), 255)
      exit
    }
  ' "$@"
}

start_capture() {
  CAPTURE_FILE="$1"
  candump -x -e "$CAN_INTERFACE" >"$CAPTURE_FILE" 2>&1 &
  CAPTURE_PID=$!
  sleep 1
  kill -0 "$CAPTURE_PID" 2>/dev/null || return 1
}

stop_capture() {
  sleep "$RESPONSE_TIMEOUT"
  kill -INT "$CAPTURE_PID" 2>/dev/null
  wait "$CAPTURE_PID" 2>/dev/null
  CAPTURE_PID=""
}

send_search_request() {
  SEARCH_CRC="$(crc16_hex 17 3 86 52 255)"
  cansend "$CAN_INTERFACE" 1FFFDA00#750807FE11035634 || return 1
  cansend "$CAN_INTERFACE" "1FFFDA01#FF$SEARCH_CRC" || return 1
}

send_device_info_request() {
  TARGET_LID="$1"
  TARGET_LID_HEX="$(awk -v value="$TARGET_LID" 'BEGIN { printf "%02X", value }')"
  REQUEST_TID_LOW="$TARGET_LID"
  REQUEST_TID_HIGH=80
  REQUEST_CRC="$(crc16_hex 17 4 "$REQUEST_TID_LOW" "$REQUEST_TID_HIGH")"
  REQUEST_CAN_ID="$(awk -v sender="$SCANNER_CAN_ID" -v address="$TARGET_LID" '
    BEGIN { printf "%08X", lshift(sender, 13) + lshift(7, 10) + lshift(address, 1) }
  ')"
  REQUEST_CAN_ID_END="$(awk -v value="$REQUEST_CAN_ID" '
    function hex_digit(c) { return index("0123456789ABCDEF", c) - 1 }
    function hex_number(text, i, value) {
      value = 0
      for (i = 1; i <= length(text); i++) value = (value * 16) + hex_digit(substr(text, i, 1))
      return value
    }
    BEGIN { printf "%08X", hex_number(value) + 1 }
  ')"
  cansend "$CAN_INTERFACE" "${REQUEST_CAN_ID}#7D0806FE${TARGET_LID_HEX}1104${TARGET_LID_HEX}" || return 1
  cansend "$CAN_INTERFACE" "${REQUEST_CAN_ID_END}#50${REQUEST_CRC}" || return 1
}

parse_search_capture() {
  awk -v scanner_lid="$SCANNER_LID" '
    function hex_digit(c) { return index("0123456789ABCDEF", toupper(c)) - 1 }
    function hex_number(text, i, value) {
      value = 0
      for (i = 1; i <= length(text); i++) value = (value * 16) + hex_digit(substr(text, i, 1))
      return value
    }
    function crc_step(crc, byte, bit) {
      crc = xor(crc, byte)
      for (bit = 0; bit < 8; bit++) {
        if (and(crc, 1)) crc = xor(rshift(crc, 1), 40961)
        else crc = rshift(crc, 1)
      }
      return crc
    }
    $2 == "RX" {
      if (length($5) != 8 || toupper($5) !~ /^[0-9A-F]+$/) next
      ext_id = hex_number($5)
      if (ext_id > 536870911) next
      if (and(rshift(ext_id, 1), 255) != scanner_lid) next
      sender = and(rshift(ext_id, 13), 65535)
      stream = sprintf("%04X:%d", sender, and(rshift(ext_id, 10), 7))
      key = stream ":" generation[stream]
      for (field = 7; field <= NF; field++) {
        if (length($field) == 2 && toupper($field) ~ /^[0-9A-F]+$/) {
          data[key, length_by_key[key]++] = hex_number($field)
        }
      }
      if (and(ext_id, 1)) { complete[key] = 1; generation[stream]++ }
    }
    END {
      for (key in length_by_key) {
        if (!complete[key]) continue
        packet_length = length_by_key[key]
        if (packet_length < 12 || and(data[key, 0], 119) != 117) continue
        flags = data[key, 1]
        body_size = data[key, 2]
        cursor = 3
        if (and(flags, 128)) cursor++
        if (and(flags, 64)) cursor++
        source_lid = data[key, cursor++]
        if (and(flags, 32)) cursor++
        if (and(data[key, 0], 8)) cursor++
        body = cursor
        if (packet_length != body + body_size || body_size < 7) continue
        crc = 65535
        for (position = body; position < body + body_size - 2; position++) crc = crc_step(crc, data[key, position])
        expected_crc = data[key, body + body_size - 2] + (data[key, body + body_size - 1] * 256)
        if (crc != expected_crc) continue
        if (and(flags, 7) || data[key, body] != 145 || data[key, body + 1] != 3) continue
        if (data[key, body + 2] != 86 || data[key, body + 3] != 52) continue
        pointer = body + 4
        group = data[key, pointer++]
        hwid = ""
        while (pointer < body + body_size - 2 && data[key, pointer] != 0) {
          hwid = hwid sprintf("%c", data[key, pointer++])
        }
        if (pointer >= body + body_size - 2) continue
        pointer++
        if (pointer + 8 > body + body_size - 2) continue
        event = data[key, pointer++]
        device_flags = data[key, pointer++]
        gsub(/[|[:cntrl:]]/, "/", hwid)
        printf "%d|%s|%s|%d|%d|%d\n", source_lid, substr(key, 1, 4), hwid, group, device_flags, event
      }
    }
  ' "$SEARCH_CAPTURE" | sort -nu >"$SEARCH_RESULTS"
}

parse_info_capture() {
  awk -v scanner_lid="$SCANNER_LID" '
    function hex_digit(c) { return index("0123456789ABCDEF", toupper(c)) - 1 }
    function hex_number(text, i, value) {
      value = 0
      for (i = 1; i <= length(text); i++) value = (value * 16) + hex_digit(substr(text, i, 1))
      return value
    }
    function crc_step(crc, byte, bit) {
      crc = xor(crc, byte)
      for (bit = 0; bit < 8; bit++) {
        if (and(crc, 1)) crc = xor(rshift(crc, 1), 40961)
        else crc = rshift(crc, 1)
      }
      return crc
    }
    function u32(key, pointer) {
      return data[key, pointer] + data[key, pointer + 1] * 256 + data[key, pointer + 2] * 65536 + data[key, pointer + 3] * 16777216
    }
    $2 == "RX" {
      if (length($5) != 8 || toupper($5) !~ /^[0-9A-F]+$/) next
      ext_id = hex_number($5)
      if (ext_id > 536870911) next
      if (and(rshift(ext_id, 1), 255) != scanner_lid) next
      sender = and(rshift(ext_id, 13), 65535)
      stream = sprintf("%04X:%d", sender, and(rshift(ext_id, 10), 7))
      key = stream ":" generation[stream]
      for (field = 7; field <= NF; field++) {
        if (length($field) == 2 && toupper($field) ~ /^[0-9A-F]+$/) {
          data[key, length_by_key[key]++] = hex_number($field)
        }
      }
      if (and(ext_id, 1)) { complete[key] = 1; generation[stream]++ }
    }
    END {
      for (key in length_by_key) {
        if (!complete[key]) continue
        packet_length = length_by_key[key]
        if (packet_length < 20 || and(data[key, 0], 119) != 117) continue
        flags = data[key, 1]
        body_size = data[key, 2]
        cursor = 3
        if (and(flags, 128)) cursor++
        if (and(flags, 64)) cursor++
        source_lid = data[key, cursor++]
        if (and(flags, 32)) cursor++
        if (and(data[key, 0], 8)) cursor++
        body = cursor
        if (packet_length != body + body_size || body_size < 16) continue
        crc = 65535
        for (position = body; position < body + body_size - 2; position++) crc = crc_step(crc, data[key, position])
        expected_crc = data[key, body + body_size - 2] + (data[key, body + body_size - 1] * 256)
        if (crc != expected_crc) continue
        if (and(flags, 7) || and(data[key, body], 223) != 145 || data[key, body + 1] != 4) continue
        if (and(data[key, body], 32)) {
          pointer = body + 2
        } else {
          if (data[key, body + 2] != source_lid || data[key, body + 3] != 80) continue
          pointer = body + 4
        }
        group = data[key, pointer++]
        name = ""
        while (pointer < body + body_size - 2 && data[key, pointer] != 0) name = name sprintf("%c", data[key, pointer++])
        pointer++
        producer = ""
        while (pointer < body + body_size - 2 && data[key, pointer] != 0) producer = producer sprintf("%c", data[key, pointer++])
        pointer++
        model = ""
        while (pointer < body + body_size - 2 && data[key, pointer] != 0) model = model sprintf("%c", data[key, pointer++])
        pointer++
        hwid = ""
        while (pointer < body + body_size - 2 && data[key, pointer] != 0) hwid = hwid sprintf("%c", data[key, pointer++])
        pointer++
        if (pointer + 22 > body + body_size - 2) continue
        device_class = data[key, pointer++]
        processor = data[key, pointer++]
        operating_system = data[key, pointer++]
        device_flags = data[key, pointer++]
        firmware_id = data[key, pointer] + data[key, pointer + 1] * 256
        pointer += 2
        version_major = data[key, pointer++]
        version_minor = data[key, pointer++]
        channels = u32(key, pointer)
        pointer += 4
        tags = u32(key, pointer)
        pointer += 4
        user_id = u32(key, pointer)
        pointer += 4
        change = data[key, pointer] + data[key, pointer + 1] * 256
        gsub(/[|[:cntrl:]]/, "/", name)
        gsub(/[|[:cntrl:]]/, "/", producer)
        gsub(/[|[:cntrl:]]/, "/", model)
        gsub(/[|[:cntrl:]]/, "/", hwid)
        printf "%d|%s|%s|%s|%s|%s|%d|%d.%d|%d|%d|%d|%d|%d|%d|%d|%d\n", source_lid, substr(key, 1, 4), name, producer, model, hwid, firmware_id, version_major, version_minor, channels, tags, group, device_class, processor, operating_system, device_flags, user_id
      }
    }
  ' "$INFO_CAPTURE" | awk -F'|' 'NR == FNR {expected[$1 FS $2 FS $3]=1; next} expected[$1 FS $2 FS $6]' "$SEARCH_RESULTS" - | sort -nu >"$INFO_RESULTS"
}

separator
printf '2. Bus77 Search discovery\n'
printf '  Sending one broadcast System Search request.\n'
if ! start_capture "$SEARCH_CAPTURE"; then
  printf 'RESULT: FAIL - NOT OK: packet capture could not start; no requests sent.\n'
  exit 2
fi
if awk '
  function hex(s, i, n) { n=0; for(i=1;i<=length(s);i++) n=n*16+index("0123456789ABCDEF",toupper(substr(s,i,1)))-1; return n }
  $2 == "RX" && length($5) == 8 {
    if (and(rshift(hex($5),13),65535) == 65534) collision=1
    if ($7 == "75" || $7 == "7D") {
      flags=hex($8); pos=10
      if(and(flags,128)) pos++
      if(and(flags,64)) pos++
      if(hex($pos)==254) collision=1
    }
  }
  END { exit !collision }
' "$SEARCH_CAPTURE"; then
  printf 'RESULT: FAIL - NOT OK: scanner identity already observed on the bus; no requests sent.\n'
  exit 2
fi
printf '  Identity was not observed in the preflight sample; silent conflicts cannot be excluded.\n'
if send_search_request; then
  ok 'Search request sent successfully (2 CAN frames).'
else
  fail 'Search request could not be sent.'
fi
stop_capture

if [ "$FAILURES" -eq 0 ]; then
  parse_search_capture
fi
SEARCH_COUNT="$(wc -l <"$SEARCH_RESULTS" 2>/dev/null | tr -d ' ')"
SEARCH_COUNT="${SEARCH_COUNT:-0}"
if [ "$SEARCH_COUNT" -eq 0 ]; then
  fail 'No valid Bus77 Search responses were received.'
else
  ok "$SEARCH_COUNT devices responded with valid CRC-protected Search data."
  printf '\n  %-4s %-8s %-34s %-5s %-5s\n' 'LID' 'CAN ID' 'HWID' 'Group' 'Flags'
  while IFS='|' read -r LID CAN_ID HWID GROUP DEVICE_FLAGS EVENT; do
    printf '  %-4s 0x%-6s %-34s %-5s 0x%02X\n' "$LID" "$CAN_ID" "$HWID" "$GROUP" "$DEVICE_FLAGS"
  done <"$SEARCH_RESULTS"
fi

separator
printf '3. Device information\n'
if [ "$SEARCH_COUNT" -gt 0 ]; then
  printf '  Requesting Device Info from every discovered LID.\n'
  if ! start_capture "$INFO_CAPTURE"; then
    printf 'RESULT: FAIL - NOT OK: packet capture could not start for Device Info.\n'
    exit 2
  fi
  REQUESTED_COUNT=0
  while IFS='|' read -r LID CAN_ID HWID GROUP DEVICE_FLAGS EVENT; do
    if [ "$LID" -eq 0 ] || [ "$LID" -ge 254 ] || [ "$(awk -F'|' -v lid="$LID" '$1 == lid {n++} END {print n+0}' "$SEARCH_RESULTS")" -ne 1 ]; then
      warn "Skipping ambiguous or reserved LID $LID; profile requires individual addressing."
      continue
    fi
    if send_device_info_request "$LID"; then
      REQUESTED_COUNT=$((REQUESTED_COUNT + 1))
    else
      warn "Device Info request to LID $LID could not be sent."
    fi
    sleep 1
  done <"$SEARCH_RESULTS"
  stop_capture
  parse_info_capture
else
  REQUESTED_COUNT=0
  : >"$INFO_RESULTS"
fi

INFO_COUNT="$(wc -l <"$INFO_RESULTS" 2>/dev/null | tr -d ' ')"
INFO_COUNT="${INFO_COUNT:-0}"
if [ "$SEARCH_COUNT" -eq 0 ]; then
  :
elif [ "$INFO_COUNT" -eq 0 ]; then
  fail 'No valid Device Info responses were decoded.'
elif [ "$INFO_COUNT" -lt "$SEARCH_COUNT" ]; then
  warn "Decoded Device Info for $INFO_COUNT of $SEARCH_COUNT discovered devices."
else
  ok "Decoded Device Info for all $INFO_COUNT discovered devices."
fi

if [ -n "${IRIDI_BUS77_INVENTORY_FILE:-}" ]; then
  cat "$INFO_RESULTS" >"$IRIDI_BUS77_INVENTORY_FILE" || warn 'Could not export inventory for the traffic decoder.'
fi
if [ "$INFO_COUNT" -gt 0 ]; then
  printf '\n  %-4s %-24s %-10s %-8s %s\n' 'LID' 'MODEL' 'FIRMWARE' 'PROFILE' 'CAN ID'
  awk -F'|' '{printf "  %-4s %-24s %-10s %-8s 0x%s\n", $1, $5, $8, $7, $2}' "$INFO_RESULTS"
  while IFS='|' read -r LID CAN_ID NAME PRODUCER MODEL HWID FIRMWARE_ID VERSION CHANNELS TAGS GROUP DEVICE_CLASS PROCESSOR OPERATING_SYSTEM DEVICE_FLAGS USER_ID; do
    printf '\n  LID %s | %s\n' "$LID" "${MODEL:-unknown model}"
    printf '    Name:             %s\n' "${NAME:-not set}"
    printf '    Producer:         %s\n' "${PRODUCER:-not set}"
    printf '    HWID:             %s\n' "${HWID:-not set}"
    printf '    CAN device ID:    0x%s\n' "$CAN_ID"
    printf '    Firmware version: %s\n' "$VERSION"
    printf '    Firmware profile: %s (Firmware ID)\n' "$FIRMWARE_ID"
    printf '    Channels / tags:  %s / %s\n' "$CHANNELS" "$TAGS"
    printf '    Group/class:      %s / %s\n' "$GROUP" "$DEVICE_CLASS"
    printf '    Processor / OS:   %s / %s\n' "$PROCESSOR" "$OPERATING_SYSTEM"
    printf '    User ID:          %s\n' "$USER_ID"
  done <"$INFO_RESULTS"
fi

separator
printf 'SUMMARY\n'
printf '  Discovered devices: %s\n' "$SEARCH_COUNT"
printf '  Complete profiles:  %s\n' "$INFO_COUNT"
printf '  Read-only requests: 1 Search, %s Device Info\n' "$REQUESTED_COUNT"
printf '  Write operations:   none\n'
printf '  Failures:           %s\n' "$FAILURES"
printf '  Attention items:    %s\n' "$WARNINGS"
if [ "$FAILURES" -gt 0 ]; then
  printf 'RESULT: FAIL - NOT OK: Bus77 discovery could not be completed.\n'
  exit 2
fi
if [ "$WARNINGS" -gt 0 ]; then
  printf 'RESULT: WARN - ATTENTION REQUIRED: discovery completed with incomplete or questionable data.\n'
  exit 1
fi
printf 'RESULT: PASS - OK: all discovered Bus77 devices returned complete valid profiles.\n'
exit 0

)
# END GENERATED INVENTORY

# BEGIN GENERATED DECODER
decode_bus77_traffic() {
  awk -v inventory="$INVENTORY_FILE" -v status="$WORK_DIR/decoder.status" '
# Protocol reference: iRidium-Mobile/BUS77-SDK, Iridium.h, IridiumBus.h,
# CInBuffer::GetValue. Independent decoder; unsupported data is not guessed.
function hx(s, i,n) { n=0; for(i=1;i<=length(s);i++) n=n*16+index("0123456789ABCDEF",toupper(substr(s,i,1)))-1; return n }
function pow2(n, i,r) { if(n in powers)return powers[n];r=1;for(i=0;i<n;i++)r*=2;for(i=0;i>n;i--)r/=2;powers[n]=r;return r }
function bit(n,p) { return int(n/pow2(p))%2 }
function bxor(a,b, n,p) { n=0;p=1;while(a||b){if(a%2!=b%2)n+=p;a=int(a/2);b=int(b/2);p*=2}return n }
function crcstep(c,b,i) { c=bxor(c,b);for(i=0;i<8;i++)c=bxor(int(c/2),c%2?40961:0);return c }
function uint(p,size, i,n) { n=0;for(i=0;i<size;i++)n+=bytes[p+i]*pow2(8*i);return n }
function raw(p,end, i,s) { s="";for(i=p;i<end;i++)s=s sprintf("%02X",bytes[i]) (i+1<end?" ":"");return s }
function clean(s) { gsub(/[[:cntrl:]|]/,"?",s);return s }
function label(dev,addr,can,local, k,s) {
    s=(addr>=256?"S" int(addr/256) ":":"") "LID " addr%256
    if(local || servers[dev SUBSEP addr]) return "SERVER/GW(" s ")"
    k=dev SUBSEP addr
    if(addr<256 && names[k]!="" && names[k]!="AMBIGUOUS" && (can=="" || identities[k]==can)) s=s " " names[k]
    if(can!="") s=s " [" can "]"
    return s
}
function value(p,end, t,present,size,n,exponent,mantissa,i,s) {
    value_end=p; value_ok=0
    if(p>=end)return "<missing value>"
    t=bytes[p]%128;present=bit(bytes[p++],7);value_end=p
    if(t==0){value_ok=1;return "NONE"}
    if(t==1){value_ok=1;return present?"true":"false"}
    if(t==2||t==3)size=1
    else if(t==4||t==5)size=2
    else if(t==6||t==7||t==8)size=4
    else if(t==9||t==10||t==11)size=8
    else if(t==12||t==15){
        if(!present){value_ok=1;return t==12?"\"\"":"[]"}
        if(p+2>end)return "<truncated length>"
        size=uint(p,2);p+=2
        if(p+size>end)return "<truncated string/array>"
        value_end=p+size;value_ok=1
        if(t==15)return "bytes[" raw(p,p+size) "]"
        s="";for(i=p;i<p+size;i++)if(bytes[i])s=s sprintf("%c",bytes[i])
        return "\"" clean(s) "\""
    } else return "<unsupported type " t ">"
    if(!present){value_ok=1;return "0"}
    if(p+size>end)return "<truncated value>"
    value_end=p+size;value_ok=1
    if(t==9||t==10||t==11)return "type=" t " LE-hex=" raw(p,p+size)
    n=uint(p,size)
    if(t==2||t==4||t==6){if(n>=pow2(size*8-1))n-=pow2(size*8);return sprintf("%.0f",n)}
    if(t!=8)return sprintf("%.0f",n)
    exponent=int(n/8388608)%256;mantissa=n%8388608
    if(exponent==255)return mantissa?"NaN":(bit(n,31)?"-Inf":"+Inf")
    n=(exponent?1+mantissa/8388608:mantissa/8388608)*pow2((exponent?exponent:1)-127)
    return sprintf("%.7g",n*(bit(bytes[p+3],7)?-1:1))
}
function details(cmd,response,p,end, s,id,v) {
    # Never print session tokens, firmware streams or address-assignment payloads.
    if(cmd==8||cmd==5||cmd==80||cmd==81||cmd==82)return "payload hidden (sensitive/control data)"
    if(p==end)return response?"acknowledgement":"no payload"
    if(cmd==16&&!response){
        v=value(p,end);p=value_end
        if(value_ok&&p+2<=end)return "variable=" uint(p,2) " value=" v
        return "unparsed variable payload"
    }
    if(cmd==17&&p+2<=end){
        s="variable=" uint(p,2);p+=2
        if(response)s=s " value=" value(p,end)
        return s
    }
    if((cmd==38||cmd==39||cmd==51||cmd==54)&&p+4<=end){
        s=(cmd==38||cmd==39?"tag=":"channel=") uint(p,4);p+=4
        if((!response&&(cmd==38||cmd==51))||(response&&(cmd==39||cmd==54)))s=s " value=" value(p,end)
        # Any remaining bytes may include an access PIN; do not emit them.
        return s
    }
    if((cmd==37||cmd==53)&&p+4<=end)return "id=" uint(p,4) " data=" raw(p+4,end)
    if(cmd==3&&!response)return sprintf("capability mask=0x%02X",bytes[p])
    return "data=" raw(p,end)
}
function report_bad(reason) {
    bad++;printf "%s %-5s %-2s [ATTENTION] CAN %s: %s\n",strftime("%H:%M:%S"),dev,direction,can,reason;fflush()
}
function packet(n, i,flags,p,srcseg,src,dstseg,dst,body,end,c,cmd,mflags,response,tid,from,to,what,route,k) {
    if(n<8 || bytes[0]%128!=117 && bytes[0]%128!=125){report_bad("not a complete supported Bus77 packet");return}
    flags=bytes[1];p=3
    if(bit(flags,7))p++
    srcseg=0;if(bit(flags,6))srcseg=bytes[p++]
    src=srcseg*256+bytes[p++]
    dstseg=0;if(bit(flags,5))dstseg=bytes[p++]
    dst=bit(bytes[0],3)?dstseg*256+bytes[p++]:-1
    body=p;end=body+bytes[2]-2
    if(int(flags/8)%4>1 || n!=end+2 || end<body+2){report_bad("unsupported header or incomplete packet");return}
    c=65535;for(i=body;i<end;i++)c=crcstep(c,bytes[i])
    if(c!=uint(end,2)){report_bad("CRC mismatch; payload not decoded");return}
    if(direction=="TX")servers[dev SUBSEP src]=1
    from=label(dev,src,can,direction=="TX")
    to=dst<0?"ALL (broadcast)":label(dev,dst,"",0)
    if(flags%8){what="ENCRYPTED (not decoded)"}
    else {
        mflags=bytes[p++];cmd=bytes[p++];response=bit(mflags,7)
        if(mflags%16!=1){report_bad("unsupported message version");return}
        tid="none";if(!bit(mflags,5)){if(p+2>end){report_bad("missing transaction ID");return};tid=uint(p,2);p+=2}
        what=(response?"RESPONSE ":"REQUEST ") (commands[cmd]!=""?commands[cmd]:sprintf("UNKNOWN_0x%02X",cmd)) " tid=" tid
        if(cmd==8||cmd==5||cmd==80||cmd==81||cmd==82)what=what " | payload hidden (sensitive/control data)"
        else if(bit(mflags,6))what=what " ERROR data=" raw(p,end)
        else if(!bit(mflags,4))what=what " MORE (message fragment) data=" raw(p,end)
        else what=what " | " details(cmd,response,p,end)
    }
    printf "%s %-5s %-2s %s -> %s | %s\n",strftime("%H:%M:%S"),dev,direction,from,to,what
    good++;route=dev SUBSEP from SUBSEP to;routes[route]++
    fflush()
}
BEGIN {
    commands[2]="Ping";commands[3]="Search";commands[4]="DeviceInfo";commands[5]="SetLID";commands[8]="SessionToken";commands[10]="SmartAPI";commands[11]="Blink"
    commands[16]="SetVariable";commands[17]="GetVariable";commands[18]="DeleteVariables"
    commands[32]="GetTags";commands[36]="LinkTagVariable";commands[37]="GetTagDescription";commands[38]="SetTagValue";commands[39]="GetTagValue"
    commands[48]="GetChannels";commands[51]="SetChannelValue";commands[52]="LinkChannelVariable";commands[53]="GetChannelDescription";commands[54]="GetChannelValue"
    commands[80]="StreamOpen";commands[81]="StreamBlock";commands[82]="StreamClose";commands[96]="GetScenarios";commands[97]="GetScenario";commands[98]="SetScenario"
    if(inventory!="")while((getline line < inventory)>0){
        split(line,f,"|");k=f[1] SUBSEP f[2]
        if(names[k]!=""&&identities[k]!=f[3])names[k]="AMBIGUOUS"
        else if(names[k]!="AMBIGUOUS"){names[k]=clean(f[6]);identities[k]=f[3]}
    }
    close(inventory)
}
$2=="RX" || $2=="TX" {
    dev=$1;direction=$2;id=toupper($5);can=id
    if(length(id)!=8||id!~/^[01][0-9A-F]+$/){report_bad("CAN error or non-extended frame (not decoded)");next}
    number=hx(id);can=sprintf("%04X",int(number/8192)%65536)
    key=dev SUBSEP direction SUBSEP int(number/2)
    for(i=7;i<=NF;i++)if(length($i)==2&&toupper($i)~/^[0-9A-F]+$/){
        if(count[key]<264)data[key,count[key]++]=hx($i);else overflow[key]=1
    }
    if(number%2){
        if(overflow[key])report_bad("oversized/reassembly gap")
        else{for(i=0;i<count[key];i++)bytes[i]=data[key,i];packet(count[key])}
        for(i=0;i<count[key];i++)delete data[key,i]
        delete count[key];delete overflow[key]
    }
    next
}
{ if($0!="") {bad++;print "[ATTENTION] Capture: " clean($0);fflush()} }
END {
    for(k in count)if(count[k])incomplete++
    printf "\nDecoded traffic routes (Bus77 packets, not CAN frames):\n"
    for(k in routes){split(k,f,SUBSEP);printf "  %s %s -> %s : %d packets\n",f[1],f[2],f[3],routes[k]}
    printf "Decoder: %d valid packets, %d undecoded/corrupt frames or packets, %d unfinished packets.\n",good,bad,incomplete
    if(status!=""){printf "%d\n",bad+incomplete > status;close(status)}
    fflush()
}
'
}
# END GENERATED DECODER

cleanup() {
  if [ -n "$CAPTURE_PID" ]; then
    kill -INT "$CAPTURE_PID" 2>/dev/null
    wait "$CAPTURE_PID" 2>/dev/null
  fi
  [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

while [ "$#" -gt 0 ]; do
  case "$1" in
    --passive) PASSIVE_ONLY=1 ;;
    --interface)
      [ "$#" -ge 2 ] || { printf 'RESULT: FAIL - missing interface.\n'; exit 2; }
      shift
      REQUESTED_INTERFACE="${1:-}"
      ;;
    --duration)
      [ "$#" -ge 2 ] || { printf 'RESULT: FAIL - missing duration.\n'; exit 2; }
      shift
      MONITOR_SECONDS="${1:-}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf '[NOT OK] Unknown argument: %s\n' "$1"
      usage
      printf 'RESULT: FAIL - NOT OK: invalid command-line arguments.\n'
      exit 2
      ;;
  esac
  shift
done

case "$MONITOR_SECONDS" in
  ''|*[!0-9]*)
    printf '[NOT OK] Duration must be a whole number of seconds.\n'
    printf 'RESULT: FAIL - NOT OK: invalid monitor duration.\n'
    exit 2
    ;;
esac
if [ "$MONITOR_SECONDS" -lt 1 ] || [ "$MONITOR_SECONDS" -gt 86400 ]; then
  printf '[NOT OK] Duration must be between 1 and 86400 seconds.\n'
  printf 'RESULT: FAIL - NOT OK: invalid monitor duration.\n'
  exit 2
fi
case "$REQUESTED_INTERFACE" in
  all) : ;;
  ''|*[!A-Za-z0-9_.:-]*)
    printf '[NOT OK] Invalid interface name: %s\n' "$REQUESTED_INTERFACE"
    printf 'RESULT: FAIL - NOT OK: invalid CAN interface name.\n'
    exit 2
    ;;
esac

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/iridi-can-monitor.XXXXXX" 2>/dev/null)"
if [ -z "$WORK_DIR" ] || [ ! -d "$WORK_DIR" ]; then
  WORK_DIR="${TMPDIR:-/tmp}/iridi-can-monitor.$$"
  mkdir -m 700 "$WORK_DIR" || { WORK_DIR=""; exit 2; }
fi
CAPTURE_FILE="$WORK_DIR/capture.txt"
INVENTORY_FILE="$WORK_DIR/inventory.txt"
: >"$INVENTORY_FILE"

detect_interfaces() {
  for CAN_PATH in /sys/class/net/*; do
    [ -e "$CAN_PATH" ] || continue
    [ "$(cat "$CAN_PATH/type" 2>/dev/null)" = "280" ] || continue
    printf '%s\n' "${CAN_PATH##*/}"
  done
}

DETECTED_INTERFACES="$(detect_interfaces)"
if [ "$REQUESTED_INTERFACE" = "all" ]; then
  INTERFACES="$DETECTED_INTERFACES"
else
  INTERFACES="$REQUESTED_INTERFACE"
fi

printf 'iRidi CAN/Bus77 Live Monitor\n'
printf 'Script version: %s\n' "$SCRIPT_VERSION"
printf 'Started: %s\n' "$(date 2>/dev/null || echo unknown)"
printf 'Device: %s | %s | %s\n' "$(hostname 2>/dev/null || echo unknown)" "$(uname -s 2>/dev/null)" "$(uname -m 2>/dev/null)"
printf 'Log file: %s\n' "${IRIDI_CAN_MONITOR_LOG_FILE:-not set}"
if [ "$PASSIVE_ONLY" -eq 1 ]; then
  printf 'Mode: passive only; no CAN frames are transmitted\n'
else
  printf 'Mode: read-only identity requests, then passive decoded monitoring\n'
fi
printf 'Monitor duration: %s seconds\n' "$MONITOR_SECONDS"

if [ -z "$INTERFACES" ]; then
  fail 'No SocketCAN interfaces were detected.'
fi
if [ "$REQUESTED_INTERFACE" != "all" ]; then
  if [ ! -d "/sys/class/net/$REQUESTED_INTERFACE" ] || [ "$(cat "/sys/class/net/$REQUESTED_INTERFACE/type" 2>/dev/null)" != "280" ]; then
    fail "Interface $REQUESTED_INTERFACE is not an available SocketCAN interface."
    INTERFACES=""
  fi
fi
if ! command -v candump >/dev/null 2>&1; then
  fail 'candump is required for live packet monitoring.'
fi
if ! command -v ip >/dev/null 2>&1; then
  fail 'ip is required to inspect the CAN controller.'
fi
if ! awk 'BEGIN {print strftime("%H:%M:%S"); fflush()}' >/dev/null 2>&1; then
  fail 'awk with strftime and fflush is required (available in the supported BusyBox firmware).'
fi

snapshot_stats() {
  SNAPSHOT_INTERFACE="$1"
  SNAPSHOT_FILE="$2"
  : >"$SNAPSHOT_FILE"
  for SNAPSHOT_FIELD in rx_packets rx_bytes rx_errors rx_dropped tx_packets tx_bytes tx_errors tx_dropped; do
    SNAPSHOT_VALUE="$(cat "/sys/class/net/$SNAPSHOT_INTERFACE/statistics/$SNAPSHOT_FIELD" 2>/dev/null)"
    printf '%s=%s\n' "$SNAPSHOT_FIELD" "${SNAPSHOT_VALUE:-0}" >>"$SNAPSHOT_FILE"
  done
}

read_snapshot() {
  awk -F= -v key="$2" '$1 == key { print $2; exit }' "$1" 2>/dev/null
}

can_state() {
  ip -details link show "$1" 2>/dev/null | awk '
    /can .* state / {
      for (i = 1; i <= NF; i++) if ($i == "state") { print $(i + 1); exit }
    }
  '
}

separator
printf 'Selected interfaces and initial state\n'
for CAN_INTERFACE in $INTERFACES; do
  snapshot_stats "$CAN_INTERFACE" "$WORK_DIR/$CAN_INTERFACE.before"
  INITIAL_STATE="$(can_state "$CAN_INTERFACE")"
  INITIAL_BITRATE="$(ip -details link show "$CAN_INTERFACE" 2>/dev/null | awk '/ bitrate / { for (i=1;i<=NF;i++) if ($i=="bitrate") {print $(i+1); exit} }')"
  printf '  %s: state=%s, bitrate=%s bit/s\n' "$CAN_INTERFACE" "${INITIAL_STATE:-not determined}" "${INITIAL_BITRATE:-not determined}"
  case "$INITIAL_STATE" in
    BUS-OFF|STOPPED) fail "$CAN_INTERFACE is currently $INITIAL_STATE." ;;
    ERROR-WARNING|ERROR-PASSIVE) warn "$CAN_INTERFACE is currently $INITIAL_STATE." ;;
  esac
done

separator
printf 'DEVICE DIRECTORY\n'
if [ "$PASSIVE_ONLY" -eq 1 ]; then
  printf '  Passive mode: devices are identified by their bus addresses.\n'
elif [ "$FAILURES" -eq 0 ]; then
  for INVENTORY_INTERFACE in $INTERFACES; do
    printf '  %s: reading device names and models...\n' "$INVENTORY_INTERFACE"
    IRIDI_BUS77_INVENTORY_FILE="$WORK_DIR/device.rows" run_bus77_inventory --interface "$INVENTORY_INTERFACE" >"$WORK_DIR/inventory.report" 2>&1
    INVENTORY_RC=$?
    if [ -s "$WORK_DIR/device.rows" ]; then
      awk -F'|' -v dev="$INVENTORY_INTERFACE" '{print dev "|" $0}' "$WORK_DIR/device.rows" >>"$INVENTORY_FILE"
      awk -F'|' '{printf "  LID %-3s %-24s name=%s | firmware=%s profile=%s\n",$1,$5,$3,$8,$7}' "$WORK_DIR/device.rows"
    fi
    if [ "$INVENTORY_RC" -ne 0 ]; then
      warn "$INVENTORY_INTERFACE directory is incomplete; unknown devices will retain their bus addresses."
      awk '/\[NOT OK\]/ || /\[ATTENTION\]/ {print}' "$WORK_DIR/inventory.report"
    fi
    : >"$WORK_DIR/device.rows"
  done
fi

separator
printf 'Live packet exchange\n'
printf '  TIME | CAN | RX/TX | SENDER -> RECEIVER | COMMAND | CHANNEL/VARIABLE/VALUE\n'
printf '  RX/TX is relative to this server; ALL means a broadcast, not an acknowledgement.\n'
printf '  S3:LID 0 means segment 3, local address 0; SERVER/GW may forward upstream clients.\n'
printf '  Unknown payloads remain hex; partial/corrupt packets are explicitly marked.\n'
printf '  Monitoring starts now and stops automatically after %s seconds.\n' "$MONITOR_SECONDS"
separator
for CAN_INTERFACE in $INTERFACES; do
  snapshot_stats "$CAN_INTERFACE" "$WORK_DIR/$CAN_INTERFACE.before"
done

if [ "$FAILURES" -eq 0 ]; then
  if command -v timeout >/dev/null 2>&1 && command -v tee >/dev/null 2>&1; then
    timeout "$MONITOR_SECONDS" candump -x -e $INTERFACES 2>&1 | tee "$CAPTURE_FILE" | decode_bus77_traffic
  else
    warn 'Live streaming support is limited because timeout or tee is unavailable; output will be shown after capture.'
    candump -x -e $INTERFACES >"$CAPTURE_FILE" 2>&1 &
    CAPTURE_PID=$!
    sleep "$MONITOR_SECONDS"
    kill -INT "$CAPTURE_PID" 2>/dev/null
    wait "$CAPTURE_PID" 2>/dev/null
    CAPTURE_PID=""
    decode_bus77_traffic <"$CAPTURE_FILE"
  fi
fi

separator
printf 'Traffic and error summary\n'
if [ ! -s "$WORK_DIR/decoder.status" ]; then
  fail 'The Bus77 decoder did not complete successfully.'
elif [ "$(cat "$WORK_DIR/decoder.status")" -gt 0 ]; then
  warn 'Some traffic could not be decoded completely; see decoder notices above.'
fi
TOTAL_CAPTURED="$(awk '$2 == "RX" || $2 == "TX" { count++ } END { print count + 0 }' "$CAPTURE_FILE" 2>/dev/null)"
TOTAL_RX_CAPTURED="$(awk '$2 == "RX" { count++ } END { print count + 0 }' "$CAPTURE_FILE" 2>/dev/null)"
TOTAL_TX_CAPTURED="$(awk '$2 == "TX" { count++ } END { print count + 0 }' "$CAPTURE_FILE" 2>/dev/null)"
TOTAL_ERROR_CAPTURED="$(awk '($2 == "RX" || $2 == "TX") && toupper($5) ~ /^2/ { count++ } END { print count + 0 }' "$CAPTURE_FILE" 2>/dev/null)"
printf '  Captured frames: %s total, %s RX, %s TX, %s CAN error frames\n' "$TOTAL_CAPTURED" "$TOTAL_RX_CAPTURED" "$TOTAL_TX_CAPTURED" "$TOTAL_ERROR_CAPTURED"

for CAN_INTERFACE in $INTERFACES; do
  snapshot_stats "$CAN_INTERFACE" "$WORK_DIR/$CAN_INTERFACE.after"
  BEFORE_FILE="$WORK_DIR/$CAN_INTERFACE.before"
  AFTER_FILE="$WORK_DIR/$CAN_INTERFACE.after"
  RX_DELTA=$(($(read_snapshot "$AFTER_FILE" rx_packets) - $(read_snapshot "$BEFORE_FILE" rx_packets)))
  TX_DELTA=$(($(read_snapshot "$AFTER_FILE" tx_packets) - $(read_snapshot "$BEFORE_FILE" tx_packets)))
  RX_ERRORS_DELTA=$(($(read_snapshot "$AFTER_FILE" rx_errors) - $(read_snapshot "$BEFORE_FILE" rx_errors)))
  TX_ERRORS_DELTA=$(($(read_snapshot "$AFTER_FILE" tx_errors) - $(read_snapshot "$BEFORE_FILE" tx_errors)))
  RX_DROPPED_DELTA=$(($(read_snapshot "$AFTER_FILE" rx_dropped) - $(read_snapshot "$BEFORE_FILE" rx_dropped)))
  TX_DROPPED_DELTA=$(($(read_snapshot "$AFTER_FILE" tx_dropped) - $(read_snapshot "$BEFORE_FILE" tx_dropped)))
  FINAL_STATE="$(can_state "$CAN_INTERFACE")"
  printf '  %s: kernel RX=%s, TX=%s, new errors RX/TX=%s/%s, new drops RX/TX=%s/%s, state=%s\n' \
    "$CAN_INTERFACE" "$RX_DELTA" "$TX_DELTA" "$RX_ERRORS_DELTA" "$TX_ERRORS_DELTA" \
    "$RX_DROPPED_DELTA" "$TX_DROPPED_DELTA" "${FINAL_STATE:-not determined}"
  case "$FINAL_STATE" in
    BUS-OFF|STOPPED) fail "$CAN_INTERFACE ended in state $FINAL_STATE." ;;
    ERROR-WARNING|ERROR-PASSIVE) warn "$CAN_INTERFACE ended in state $FINAL_STATE." ;;
  esac
  if [ "$RX_ERRORS_DELTA" -gt 0 ] || [ "$TX_ERRORS_DELTA" -gt 0 ] || [ "$RX_DROPPED_DELTA" -gt 0 ] || [ "$TX_DROPPED_DELTA" -gt 0 ]; then
    warn "$CAN_INTERFACE recorded new errors or dropped frames during monitoring."
  fi
done

if [ "$TOTAL_CAPTURED" -eq 0 ] && [ "$FAILURES" -eq 0 ]; then
  warn 'No CAN frames were captured during the monitoring interval.'
elif [ "$TOTAL_RX_CAPTURED" -eq 0 ] && [ "$TOTAL_TX_CAPTURED" -gt 0 ]; then
  warn 'Only transmitted frames were observed; no physical bus responses were received.'
elif [ "$TOTAL_TX_CAPTURED" -eq 0 ] && [ "$TOTAL_RX_CAPTURED" -gt 0 ]; then
  warn 'Only received frames were observed; no local server transmissions were captured.'
else
  ok 'Bidirectional CAN packet exchange was observed.'
fi
if [ "$TOTAL_ERROR_CAPTURED" -gt 0 ]; then
  warn 'One or more CAN error frames were captured.'
fi

separator
printf 'Observed bus composition\n'
printf '  CAN device ID is decoded from Extended ID bits 28..13.\n'
printf '  LID candidates come from observed Bus77 headers (not CRC-validated).\n'
printf '  Silent devices are not visible in a passive capture.\n'
for CAN_INTERFACE in $INTERFACES; do
  for DIRECTION in RX TX; do
    FAMILY_FILE="$WORK_DIR/$CAN_INTERFACE.$DIRECTION.families"
    awk -v dev="$CAN_INTERFACE" -v direction="$DIRECTION" '
      function hex_digit(value) {
        return index("0123456789ABCDEF", value) - 1
      }
      function hex_byte(value) {
        return (hex_digit(substr(value, 1, 1)) * 16) + hex_digit(substr(value, 2, 1))
      }
      function hex_number(value, position, result) {
        result = 0
        for (position = 1; position <= length(value); position++) {
          result = (result * 16) + hex_digit(substr(value, position, 1))
        }
        return result
      }
      $1 == dev && $2 == direction {
        id = toupper($5)
        if (length(id) != 8 || id !~ /^[01][0-9A-F]+$/) next
        ext_id = hex_number(id)
        family = sprintf("%04X", int(ext_id / 8192) % 65536)
        count[family]++
        seen[family, id] = 1
        marker = toupper($7)
        header_flags = hex_byte(toupper($8))
        source_field = 10
        if (int(header_flags / 128) % 2) source_field++
        if (int(header_flags / 64) % 2) source_field++
        lid = toupper($(source_field))
        if (marker ~ /^(75|7D|F5|FD)$/ && length(lid) == 2 && lid ~ /^[0-9A-F]+$/) {
          seen_lid[family, lid] = 1
        }
      }
      END {
        for (family in count) {
          ids = ""
          lids = ""
          for (key in seen) {
            split(key, parts, SUBSEP)
            if (parts[1] == family) {
              if (ids == "") ids = parts[2]
              else ids = ids "," parts[2]
            }
          }
          for (lid_key in seen_lid) {
            split(lid_key, lid_parts, SUBSEP)
            if (lid_parts[1] == family) {
              lid_label = hex_byte(lid_parts[2]) " (0x" lid_parts[2] ")"
              if (lids == "") lids = lid_label
              else lids = lids "," lid_label
            }
          }
          if (lids == "") lids = "not decoded"
          print family "|" count[family] "|" ids "|" lids
        }
      }
    ' "$CAPTURE_FILE" | sort >"$FAMILY_FILE"
    FAMILY_COUNT="$(wc -l <"$FAMILY_FILE" | tr -d ' ')"
    printf '\n  %s %s: %s CAN device IDs\n' "$CAN_INTERFACE" "$DIRECTION" "${FAMILY_COUNT:-0}"
    if [ -s "$FAMILY_FILE" ]; then
      awk -F'|' '{ printf "    CAN device ID=0x%-6s Bus77 LID candidate=%-14s frames=%-6s extended_ids=%s\n", $1, $4, $2, $3 }' "$FAMILY_FILE"
    else
      printf '    none observed\n'
    fi
  done
done

separator
printf 'SUMMARY\n'
printf '  Interfaces: %s\n' "$(printf '%s' "$INTERFACES" | tr '\n' ' ')"
printf '  Duration: %s seconds\n' "$MONITOR_SECONDS"
printf '  Captured: %s RX, %s TX, %s error frames\n' "$TOTAL_RX_CAPTURED" "$TOTAL_TX_CAPTURED" "$TOTAL_ERROR_CAPTURED"
printf '  Failures: %s\n' "$FAILURES"
printf '  Attention items: %s\n' "$WARNINGS"
if [ "$FAILURES" -gt 0 ]; then
  printf 'RESULT: FAIL - NOT OK: the CAN monitor found a critical problem or could not run.\n'
  exit 2
fi
if [ "$WARNINGS" -gt 0 ]; then
  printf 'RESULT: WARN - ATTENTION REQUIRED: traffic was monitored, but one or more findings need review.\n'
  exit 1
fi
printf 'RESULT: PASS - OK: bidirectional CAN traffic was observed without new errors.\n'
exit 0
