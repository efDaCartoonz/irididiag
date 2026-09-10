#!/bin/sh

# Passive CAN/Bus77 diagnostic for iRidi HSS and ProAV servers.
# No frames are transmitted and no interface settings are changed.
# Usage: sh check_can_bus.sh [--interface can0|all] [--duration 15]

if [ "${IRIDI_CAN_LOG_ACTIVE:-0}" != "1" ]; then
  CURRENT_DIRECTORY="$(pwd 2>/dev/null || printf '.')"
  LOG_DIRECTORY="${IRIDI_DIAG_LOG_DIR:-$CURRENT_DIRECTORY}"
  if [ ! -d "$LOG_DIRECTORY" ] || [ ! -w "$LOG_DIRECTORY" ]; then
    LOG_DIRECTORY="${TMPDIR:-/tmp}"
  fi
  HOST_LABEL="$(hostname 2>/dev/null || printf server)"
  HOST_LABEL="$(printf '%s' "$HOST_LABEL" | tr -c 'A-Za-z0-9._-' '_')"
  [ -n "$HOST_LABEL" ] || HOST_LABEL=server
  LOG_TIMESTAMP="$(date '+%Y%m%d_%H%M%S' 2>/dev/null || printf unknown_time)"
  LOG_FILE="$LOG_DIRECTORY/can_diagnostic_${HOST_LABEL}_${LOG_TIMESTAMP}_$$.log"
  export IRIDI_CAN_LOG_ACTIVE=1
  export IRIDI_CAN_LOG_FILE="$LOG_FILE"

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
SAMPLE_SECONDS=15
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
  printf '%s\n' 'Usage: sh check_can_bus.sh [--interface can0|all] [--duration SECONDS]'
  printf '%s\n' 'Defaults: all detected CAN interfaces, 15-second passive sample.'
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
      SAMPLE_SECONDS="${1:-}"
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

case "$SAMPLE_SECONDS" in
  ''|*[!0-9]*)
    printf '[NOT OK] Duration must be a whole number of seconds.\n'
    printf 'RESULT: FAIL - NOT OK: invalid sample duration.\n'
    exit 2
    ;;
esac
if [ "$SAMPLE_SECONDS" -lt 1 ] || [ "$SAMPLE_SECONDS" -gt 3600 ]; then
  printf '[NOT OK] Duration must be between 1 and 3600 seconds.\n'
  printf 'RESULT: FAIL - NOT OK: invalid sample duration.\n'
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

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/iridi-can-check.XXXXXX" 2>/dev/null)"
if [ -z "$WORK_DIR" ] || [ ! -d "$WORK_DIR" ]; then
  WORK_DIR="${TMPDIR:-/tmp}/iridi-can-check.$$"
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

printf 'iRidi CAN/Bus77 Diagnostic\n'
printf 'Script version: %s\n' "$SCRIPT_VERSION"
printf 'Started: %s\n' "$(date 2>/dev/null || echo unknown)"
printf 'Device: %s | %s | %s\n' "$(hostname 2>/dev/null || echo unknown)" "$(uname -s 2>/dev/null)" "$(uname -m 2>/dev/null)"
printf 'Log file: %s\n' "${IRIDI_CAN_LOG_FILE:-not set}"
printf 'Mode: passive only; no CAN frames are transmitted\n'
printf 'Sample duration: %s seconds\n' "$SAMPLE_SECONDS"

separator
printf '1. CAN interface discovery\n'
if [ -z "$DETECTED_INTERFACES" ]; then
  fail 'No SocketCAN interfaces were detected.'
fi
if [ -z "$INTERFACES" ]; then
  fail 'No CAN interface is available for diagnostics.'
else
  printf '  Selected interfaces: %s\n' "$(printf '%s' "$INTERFACES" | tr '\n' ' ')"
fi

if [ "$REQUESTED_INTERFACE" != "all" ]; then
  if [ ! -d "/sys/class/net/$REQUESTED_INTERFACE" ] || [ "$(cat "/sys/class/net/$REQUESTED_INTERFACE/type" 2>/dev/null)" != "280" ]; then
    fail "Interface $REQUESTED_INTERFACE is not an available SocketCAN interface."
    INTERFACES=""
  fi
fi

if ! command -v ip >/dev/null 2>&1; then
  fail 'The ip utility is required to read detailed CAN controller state.'
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

can_bitrate() {
  ip -details link show "$1" 2>/dev/null | awk '
    / bitrate / {
      for (i = 1; i <= NF; i++) if ($i == "bitrate") { print $(i + 1); exit }
    }
  '
}

can_health_counters() {
  ip -details -statistics link show "$1" 2>/dev/null | awk '
    /re-started[[:space:]]+bus-errors[[:space:]]+arbit-lost/ {
      getline
      print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6
      exit
    }
  '
}

for CAN_INTERFACE in $INTERFACES; do
  snapshot_stats "$CAN_INTERFACE" "$WORK_DIR/$CAN_INTERFACE.before"
  CAN_DETAILS="$(ip -details -statistics link show "$CAN_INTERFACE" 2>/dev/null)"
  CAN_STATE="$(can_state "$CAN_INTERFACE")"
  CAN_BITRATE="$(can_bitrate "$CAN_INTERFACE")"
  CAN_OPERSTATE="$(cat "/sys/class/net/$CAN_INTERFACE/operstate" 2>/dev/null)"
  CAN_CARRIER="$(cat "/sys/class/net/$CAN_INTERFACE/carrier" 2>/dev/null)"
  CAN_DRIVER_LINK="$(readlink "/sys/class/net/$CAN_INTERFACE/device/driver" 2>/dev/null)"
  CAN_DRIVER="${CAN_DRIVER_LINK##*/}"
  CAN_FLAGS="$(printf '%s\n' "$CAN_DETAILS" | awk '
    NR == 1 {
      line = $0
      sub(/^[^<]*</, "", line)
      sub(/>.*/, "", line)
      print line
      exit
    }
  ')"
  CAN_HEALTH="$(can_health_counters "$CAN_INTERFACE")"
  OLD_IFS=$IFS
  IFS='|'
  set -- $CAN_HEALTH
  IFS=$OLD_IFS
  CAN_RESTARTED="${1:-unknown}"
  CAN_BUS_ERRORS="${2:-unknown}"
  CAN_ARBIT_LOST="${3:-unknown}"
  CAN_ERROR_WARN="${4:-unknown}"
  CAN_ERROR_PASS="${5:-unknown}"
  CAN_BUS_OFF="${6:-unknown}"

  printf '\n  Interface: %s\n' "$CAN_INTERFACE"
  printf '    Driver:               %s\n' "${CAN_DRIVER:-not determined}"
  printf '    Link flags:           %s\n' "${CAN_FLAGS:-not determined}"
  printf '    Operational state:    %s\n' "${CAN_OPERSTATE:-not determined}"
  printf '    Carrier:              %s\n' "${CAN_CARRIER:-not determined}"
  printf '    CAN controller state: %s\n' "${CAN_STATE:-not determined}"
  printf '    Bitrate:              %s bit/s\n' "${CAN_BITRATE:-not determined}"
  printf '    Restarted:            %s\n' "$CAN_RESTARTED"
  printf '    Bus errors:           %s\n' "$CAN_BUS_ERRORS"
  printf '    Arbitration lost:     %s\n' "$CAN_ARBIT_LOST"
  printf '    Error-warning events: %s\n' "$CAN_ERROR_WARN"
  printf '    Error-passive events: %s\n' "$CAN_ERROR_PASS"
  printf '    Bus-off events:       %s\n' "$CAN_BUS_OFF"

  case "$CAN_FLAGS" in
    *UP*) : ;;
    *) fail "$CAN_INTERFACE is not administratively UP." ;;
  esac
  case "$CAN_STATE" in
    ERROR-ACTIVE) ok "$CAN_INTERFACE is currently ERROR-ACTIVE." ;;
    ERROR-WARNING|ERROR-PASSIVE) warn "$CAN_INTERFACE is currently $CAN_STATE." ;;
    BUS-OFF|STOPPED) fail "$CAN_INTERFACE is currently $CAN_STATE." ;;
    *) warn "The current CAN controller state of $CAN_INTERFACE could not be determined." ;;
  esac
  case "$CAN_ERROR_WARN:$CAN_ERROR_PASS:$CAN_BUS_OFF" in
    0:0:0|unknown:unknown:unknown) : ;;
    *) warn "$CAN_INTERFACE has recorded CAN state transitions since boot; compare repeated reports for growth." ;;
  esac
done

separator
printf '2. Active iRidi runtime and CAN gateway configuration\n'
IRIDI_PID="$(pidof iridium 2>/dev/null | awk '{print $1; exit}')"
ACTIVE_DATA_DIR=""
if [ -n "$IRIDI_PID" ]; then
  printf '  iRidi Server PID: %s\n' "$IRIDI_PID"
  printf '  Executable: %s\n' "$(readlink "/proc/$IRIDI_PID/exe" 2>/dev/null)"
  for FD_PATH in /proc/$IRIDI_PID/fd/*; do
    [ -e "$FD_PATH" ] || continue
    FD_TARGET="$(readlink "$FD_PATH" 2>/dev/null)"
    case "$FD_TARGET" in
      */DataBase/*)
        ACTIVE_DATA_DIR="${FD_TARGET%/DataBase/*}"
        break
        ;;
    esac
  done
  printf '  Active data directory: %s\n' "${ACTIVE_DATA_DIR:-not determined}"
else
  warn 'No running iridium process was detected.'
fi

GATEWAY_JSON=""
if [ -n "$ACTIVE_DATA_DIR" ] && [ -r "$ACTIVE_DATA_DIR/Documents/can_gateway.json" ]; then
  GATEWAY_JSON="$ACTIVE_DATA_DIR/Documents/can_gateway.json"
fi
if [ -n "$GATEWAY_JSON" ]; then
  printf '  Gateway configuration: %s\n' "$GATEWAY_JSON"
  for CAN_INTERFACE in $INTERFACES; do
    case "$CAN_INTERFACE" in
      can0)
        GATE_ACTIVE="$(sed -n 's/.*"Can0GateWayActive":\([^,}]*\).*/\1/p' "$GATEWAY_JSON")"
        GATE_LID="$(sed -n 's/.*"DeviceLid":\([^,}]*\).*/\1/p' "$GATEWAY_JSON")"
        GATE_UDP="$(sed -n 's/.*"UdpCan0":\([^,}]*\).*/\1/p' "$GATEWAY_JSON")"
        ;;
      can1)
        GATE_ACTIVE="$(sed -n 's/.*"Can1GateWayActive":\([^,}]*\).*/\1/p' "$GATEWAY_JSON")"
        GATE_LID="$(sed -n 's/.*"DeviceLidCan1":\([^,}]*\).*/\1/p' "$GATEWAY_JSON")"
        GATE_UDP="$(sed -n 's/.*"UdpCan1":\([^,}]*\).*/\1/p' "$GATEWAY_JSON")"
        ;;
      *) GATE_ACTIVE=unknown; GATE_LID=unknown; GATE_UDP=unknown ;;
    esac
    printf '    %s: gateway=%s, local LID=%s, UDP port=%s\n' "$CAN_INTERFACE" "${GATE_ACTIVE:-unknown}" "${GATE_LID:-unknown}" "${GATE_UDP:-unknown}"
  done
else
  warn 'The active CAN gateway configuration file was not found.'
fi

printf '  CAN gateway listeners:\n'
if command -v ss >/dev/null 2>&1; then
  ss -lntup 2>/dev/null | grep -E ':(30467|30468|65534)([[:space:]]|$)' | sed 's/^/    /' || printf '    none detected\n'
elif command -v netstat >/dev/null 2>&1; then
  netstat -lntup 2>/dev/null | grep -E ':(30467|30468|65534)([[:space:]]|$)' | sed 's/^/    /' || printf '    none detected\n'
else
  printf '    listener information unavailable\n'
fi

separator
printf '3. Passive traffic sample\n'
if [ -z "$INTERFACES" ]; then
  fail 'Traffic sampling cannot start without a CAN interface.'
elif ! command -v candump >/dev/null 2>&1; then
  warn 'candump is unavailable; only kernel counters can be evaluated.'
  sleep "$SAMPLE_SECONDS"
else
  printf '  Listening for %s seconds on: %s\n' "$SAMPLE_SECONDS" "$(printf '%s' "$INTERFACES" | tr '\n' ' ')"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$SAMPLE_SECONDS" candump -x -e $INTERFACES >"$CAPTURE_FILE" 2>&1
    CAPTURE_RC=$?
    case "$CAPTURE_RC" in 0|124|137|143) : ;; *) warn "candump exited with status $CAPTURE_RC." ;; esac
  else
    candump -x -e $INTERFACES >"$CAPTURE_FILE" 2>&1 &
    CAPTURE_PID=$!
    sleep "$SAMPLE_SECONDS"
    kill -INT "$CAPTURE_PID" 2>/dev/null
    wait "$CAPTURE_PID" 2>/dev/null
    CAPTURE_PID=""
  fi
fi

for CAN_INTERFACE in $INTERFACES; do
  snapshot_stats "$CAN_INTERFACE" "$WORK_DIR/$CAN_INTERFACE.after"
  BEFORE_FILE="$WORK_DIR/$CAN_INTERFACE.before"
  AFTER_FILE="$WORK_DIR/$CAN_INTERFACE.after"
  RX_BEFORE="$(read_snapshot "$BEFORE_FILE" rx_packets)"
  TX_BEFORE="$(read_snapshot "$BEFORE_FILE" tx_packets)"
  RX_ERRORS_BEFORE="$(read_snapshot "$BEFORE_FILE" rx_errors)"
  TX_ERRORS_BEFORE="$(read_snapshot "$BEFORE_FILE" tx_errors)"
  RX_DROPPED_BEFORE="$(read_snapshot "$BEFORE_FILE" rx_dropped)"
  TX_DROPPED_BEFORE="$(read_snapshot "$BEFORE_FILE" tx_dropped)"
  RX_AFTER="$(read_snapshot "$AFTER_FILE" rx_packets)"
  TX_AFTER="$(read_snapshot "$AFTER_FILE" tx_packets)"
  RX_ERRORS_AFTER="$(read_snapshot "$AFTER_FILE" rx_errors)"
  TX_ERRORS_AFTER="$(read_snapshot "$AFTER_FILE" tx_errors)"
  RX_DROPPED_AFTER="$(read_snapshot "$AFTER_FILE" rx_dropped)"
  TX_DROPPED_AFTER="$(read_snapshot "$AFTER_FILE" tx_dropped)"
  RX_DELTA=$((RX_AFTER - RX_BEFORE))
  TX_DELTA=$((TX_AFTER - TX_BEFORE))
  RX_ERRORS_DELTA=$((RX_ERRORS_AFTER - RX_ERRORS_BEFORE))
  TX_ERRORS_DELTA=$((TX_ERRORS_AFTER - TX_ERRORS_BEFORE))
  RX_DROPPED_DELTA=$((RX_DROPPED_AFTER - RX_DROPPED_BEFORE))
  TX_DROPPED_DELTA=$((TX_DROPPED_AFTER - TX_DROPPED_BEFORE))

  printf '\n  Interface: %s\n' "$CAN_INTERFACE"
  printf '    RX frames during sample: %s\n' "$RX_DELTA"
  printf '    TX frames during sample: %s\n' "$TX_DELTA"
  printf '    New RX/TX errors:        %s / %s\n' "$RX_ERRORS_DELTA" "$TX_ERRORS_DELTA"
  printf '    New RX/TX drops:         %s / %s\n' "$RX_DROPPED_DELTA" "$TX_DROPPED_DELTA"
  if [ "$RX_DELTA" -gt 0 ]; then
    ok "$CAN_INTERFACE received physical bus traffic during the sample."
  elif [ "$TX_DELTA" -gt 0 ]; then
    warn "$CAN_INTERFACE transmitted frames but received no frames during the sample."
  else
    warn "$CAN_INTERFACE was silent during the sample; this does not prove that the port is faulty."
  fi
  if [ "$RX_ERRORS_DELTA" -gt 0 ] || [ "$TX_ERRORS_DELTA" -gt 0 ] || [ "$RX_DROPPED_DELTA" -gt 0 ] || [ "$TX_DROPPED_DELTA" -gt 0 ]; then
    warn "$CAN_INTERFACE recorded new errors or dropped frames during the sample."
  fi
done

separator
printf '4. Observed bus participants\n'
printf '  Device candidates are grouped from received CAN identifier families.\n'
printf '  Silent devices and exact model/HWID values cannot be discovered passively.\n'
if [ ! -s "$CAPTURE_FILE" ]; then
  printf '  No captured frames are available.\n'
else
  for CAN_INTERFACE in $INTERFACES; do
    PARTICIPANT_FILE="$WORK_DIR/$CAN_INTERFACE.participants"
    awk -v dev="$CAN_INTERFACE" '
      function hex_digit(value) {
        return index("0123456789ABCDEF", value) - 1
      }
      function hex_byte(value) {
        return (hex_digit(substr(value, 1, 1)) * 16) + hex_digit(substr(value, 2, 1))
      }
      $1 == dev && $2 == "RX" {
        id = toupper($5)
        if (id ~ /^2/) next
        family = id
        if (length(id) == 8) family = substr(id, 1, 4) "xxxx"
        count[family]++
        if (!seen[family, id]) {
          if (ids[family] == "") ids[family] = id
          else ids[family] = ids[family] "," id
          seen[family, id] = 1
        }
        first_byte = toupper($7)
        second_byte = toupper($8)
        lid = toupper($11)
        if (first_byte == "7D" && second_byte == "A8" && length(lid) == 2 && lid ~ /^[0-9A-F]+$/) {
          lid_key = family SUBSEP lid
          if (!seen_lid[lid_key]) {
            lid_label = hex_byte(lid) " (0x" lid ")"
            if (lids[family] == "") lids[family] = lid_label
            else lids[family] = lids[family] "," lid_label
            seen_lid[lid_key] = 1
          }
        }
      }
      END {
        for (family in count) {
          lid_list = lids[family]
          if (lid_list == "") lid_list = "not decoded"
          print family "|" count[family] "|" ids[family] "|" lid_list
        }
      }
    ' "$CAPTURE_FILE" | sort >"$PARTICIPANT_FILE"
    PARTICIPANT_COUNT="$(wc -l <"$PARTICIPANT_FILE" | tr -d ' ')"
    printf '\n  %s: %s observed RX participant signatures\n' "$CAN_INTERFACE" "${PARTICIPANT_COUNT:-0}"
    if [ -s "$PARTICIPANT_FILE" ]; then
      awk -F'|' '{ printf "    signature=%-10s Bus77 LID candidate=%-14s frames=%-6s ids=%s\n", $1, $4, $2, $3 }' "$PARTICIPANT_FILE"
    else
      printf '    no active RX participants observed\n'
    fi
  done
fi

separator
printf 'SUMMARY\n'
printf '  Interfaces: %s\n' "$(printf '%s' "$INTERFACES" | tr '\n' ' ')"
printf '  Passive sample: %s seconds\n' "$SAMPLE_SECONDS"
printf '  Failures: %s\n' "$FAILURES"
printf '  Attention items: %s\n' "$WARNINGS"
if [ "$FAILURES" -gt 0 ]; then
  printf 'RESULT: FAIL - NOT OK: the CAN subsystem has a critical problem or could not be checked.\n'
  exit 2
fi
if [ "$WARNINGS" -gt 0 ]; then
  printf 'RESULT: WARN - ATTENTION REQUIRED: CAN is available, but one or more findings need review.\n'
  exit 1
fi
printf 'RESULT: PASS - OK: CAN is operational and traffic was observed without new errors.\n'
exit 0
