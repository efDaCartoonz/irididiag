#!/bin/sh

# Passive live CAN/Bus77 monitor for iRidi HSS and ProAV servers.
# No frames are transmitted and no interface settings are changed.
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
      /\[OK\]|RESULT: PASS/ { printf "\033[32m%s\033[0m\n", $0; next }
      /\[ATTENTION\]|RESULT: WARN/ { printf "\033[33m%s\033[0m\n", $0; next }
      /\[NOT OK\]|RESULT: FAIL/ { printf "\033[31m%s\033[0m\n", $0; next }
      { print }
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

SCRIPT_VERSION=1.0
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
  printf '%s\n' 'Defaults: all detected CAN interfaces, 60-second passive monitor.'
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
      REQUESTED_INTERFACE="${1:-}"
      ;;
    --duration)
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
  mkdir -p "$WORK_DIR" || exit 2
fi
CAPTURE_FILE="$WORK_DIR/capture.txt"

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
printf 'Mode: passive only; no CAN frames are transmitted\n'
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
printf 'Live packet exchange\n'
printf '  Columns include interface, RX/TX direction, CAN ID, length, and payload.\n'
printf '  Monitoring starts now and stops automatically after %s seconds.\n' "$MONITOR_SECONDS"
separator

if [ "$FAILURES" -eq 0 ]; then
  if command -v timeout >/dev/null 2>&1 && command -v tee >/dev/null 2>&1; then
    timeout "$MONITOR_SECONDS" candump -x -e $INTERFACES 2>&1 | tee "$CAPTURE_FILE"
  else
    warn 'Live streaming support is limited because timeout or tee is unavailable; output will be shown after capture.'
    candump -x -e $INTERFACES >"$CAPTURE_FILE" 2>&1 &
    CAPTURE_PID=$!
    sleep "$MONITOR_SECONDS"
    kill -INT "$CAPTURE_PID" 2>/dev/null
    wait "$CAPTURE_PID" 2>/dev/null
    CAPTURE_PID=""
    cat "$CAPTURE_FILE"
  fi
fi

separator
printf 'Traffic and error summary\n'
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
printf '  RX identifier families are passive device candidates, not decoded model names.\n'
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
      $1 == dev && $2 == direction {
        id = toupper($5)
        if (id ~ /^2/) next
        family = id
        if (length(id) == 8) family = substr(id, 1, 4) "xxxx"
        count[family]++
        seen[family, id] = 1
        first_byte = toupper($7)
        second_byte = toupper($8)
        lid = toupper($11)
        if (direction == "RX" && first_byte == "7D" && second_byte == "A8" && length(lid) == 2 && lid ~ /^[0-9A-F]+$/) {
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
    printf '\n  %s %s: %s participant signatures\n' "$CAN_INTERFACE" "$DIRECTION" "${FAMILY_COUNT:-0}"
    if [ -s "$FAMILY_FILE" ]; then
      awk -F'|' '{ printf "    signature=%-10s Bus77 LID candidate=%-14s frames=%-6s ids=%s\n", $1, $4, $2, $3 }' "$FAMILY_FILE"
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
