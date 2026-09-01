#!/bin/sh

# Standalone Bus77 Home cloud diagnostic.
# Usage: sh check_bus77_home.sh

set +e
export LC_ALL=C

REGION="Bus77 Home"
GATE_HOSTS="37.27.5.98 85.192.35.27"
GATE_PATTERN='(37\.27\.5\.98|85\.192\.35\.27):(9088|9089)'
MAX_ATTEMPTS=3
RETRY_DELAY=1
TOTAL=0
OK_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bus77-home.XXXXXX" 2>/dev/null)"
if [ -z "$WORK_DIR" ] || [ ! -d "$WORK_DIR" ]; then
  WORK_DIR="${TMPDIR:-/tmp}/bus77-home.$$"
  mkdir -p "$WORK_DIR" || exit 2
fi
trap 'rm -rf "$WORK_DIR"' EXIT HUP INT TERM

separator() {
  printf '%s\n' '----------------------------------------------------------------'
}

resolve_host() {
  RESOLVED_IP=""
  if command -v getent >/dev/null 2>&1; then
    RESOLVED_IP="$(getent ahostsv4 "$1" 2>/dev/null | awk 'NR==1 {print $1; exit}')"
  fi
  if [ -z "$RESOLVED_IP" ] && command -v nslookup >/dev/null 2>&1; then
    RESOLVED_IP="$(nslookup "$1" 2>/dev/null | awk '
      /^Address [0-9]+: / {ip=$3}
      /^Address: / {ip=$2}
      END {sub(/#.*/, "", ip); print ip}
    ')"
  fi
}

probe_resource() {
  RESOURCE_ID="$1"
  RESOURCE_LABEL="$2"
  RESOURCE_URL="$3"
  EXPECTED_IP="$4"
  FOLLOW_REDIRECTS="$5"
  TOTAL=$((TOTAL + 1))

  BODY_FILE="$WORK_DIR/$RESOURCE_ID.body"
  HEADER_FILE="$WORK_DIR/$RESOURCE_ID.headers"
  ERROR_FILE="$WORK_DIR/$RESOURCE_ID.error"
  RESOURCE_HOST="${RESOURCE_URL#*://}"
  RESOURCE_HOST="${RESOURCE_HOST%%/*}"
  RESOURCE_HOST="${RESOURCE_HOST%%:*}"
  resolve_host "$RESOURCE_HOST"

  ATTEMPT=1
  while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
    rm -f "$BODY_FILE" "$HEADER_FILE" "$ERROR_FILE"
    HTTP_CODE=0
    REMOTE_IP=""
    CONTENT_TYPE=""
    BODY_SIZE=0
    ELAPSED="—"
    CLIENT="none"
    CLIENT_RC=127
    HTTP_RECEIVED=no

    if command -v curl >/dev/null 2>&1; then
      CLIENT="curl"
      REDIRECT_ARGS="--max-redirs 0"
      [ "$FOLLOW_REDIRECTS" = "yes" ] && REDIRECT_ARGS="--location --max-redirs 3"
      META="$(curl --insecure $REDIRECT_ARGS --connect-timeout 6 --max-time 15 \
        --silent --show-error --header 'Accept: application/json, text/plain, */*' \
        --user-agent 'iridi-pro-cloud-check/1.1' --output "$BODY_FILE" \
        --write-out '%{http_code}|%{remote_ip}|%{content_type}|%{size_download}|%{time_total}' \
        "$RESOURCE_URL" 2>"$ERROR_FILE")"
      CLIENT_RC=$?
      OLD_IFS=$IFS
      IFS='|'
      set -- $META
      IFS=$OLD_IFS
      HTTP_CODE="${1:-0}"
      REMOTE_IP="${2:-}"
      CONTENT_TYPE="${3:-}"
      BODY_SIZE="${4:-0}"
      ELAPSED="${5:-—} s"
    elif command -v wget >/dev/null 2>&1; then
      CLIENT="wget"
      WGET_REDIRECT="--max-redirect=0"
      [ "$FOLLOW_REDIRECTS" = "yes" ] && WGET_REDIRECT="--max-redirect=3"
      WGET_TLS=""
      wget --help 2>&1 | grep -q -e '--no-check-certificate' && WGET_TLS="--no-check-certificate"
      wget $WGET_TLS $WGET_REDIRECT -T 15 -t 1 -S -O "$BODY_FILE" \
        --header='Accept: application/json, text/plain, */*' \
        --user-agent='iridi-pro-cloud-check/1.1' "$RESOURCE_URL" \
        2>"$HEADER_FILE"
      CLIENT_RC=$?
      HTTP_CODE="$(awk '/^[[:space:]]*HTTP\/[0-9.]+ [0-9][0-9][0-9]/{code=$2} END{print code+0}' "$HEADER_FILE")"
      CONTENT_TYPE="$(awk -F': ' 'tolower($1) ~ /content-type/{value=$2} END{gsub(/\r/, "", value); print value}' "$HEADER_FILE")"
      REMOTE_IP="$(sed -n 's/.*Connecting to [^ ]* (\([^):]*\).*/\1/p' "$HEADER_FILE" | head -n 1)"
      [ -f "$BODY_FILE" ] && BODY_SIZE="$(wc -c <"$BODY_FILE" | tr -d ' ')"
    else
      break
    fi

    case "$HTTP_CODE" in
      2??|3??|4??|5??) HTTP_RECEIVED=yes ;;
    esac
    [ "$HTTP_RECEIVED" = "yes" ] && break
    [ "$ATTEMPT" -ge "$MAX_ATTEMPTS" ] && break
    sleep "$RETRY_DELAY"
    ATTEMPT=$((ATTEMPT + 1))
  done

  case "$HTTP_CODE" in
    2??|3??|4??) AVAILABLE=yes ;;
    *) AVAILABLE=no ;;
  esac
  [ "$AVAILABLE" = "yes" ] && [ -z "$REMOTE_IP" ] && REMOTE_IP="$RESOLVED_IP"

  separator
  printf '%s\n' "$RESOURCE_LABEL"
  printf '  URL:             %s\n' "$RESOURCE_URL"
  printf '  DNS:             %s -> %s\n' "$RESOURCE_HOST" "${RESOLVED_IP:-не разрешён}"
  printf '  Документ. IP:    %s\n' "$EXPECTED_IP"
  printf '  Фактический IP:  %s\n' "${REMOTE_IP:-не определён}"
  printf '  HTTP-клиент:     %s\n' "$CLIENT"
  printf '  Попытка:         %s из %s\n' "$ATTEMPT" "$MAX_ATTEMPTS"
  printf '  HTTP-ответ:      %s\n' "${HTTP_CODE:-0}"
  printf '  Content-Type:    %s\n' "${CONTENT_TYPE:-не указан}"
  printf '  Полезная нагрузка: %s байт\n' "${BODY_SIZE:-0}"
  [ "$ELAPSED" != "—" ] && printf '  Время запроса:   %s\n' "$ELAPSED"

  if [ "$EXPECTED_IP" != "динамический" ] && [ -n "$REMOTE_IP" ] && [ "$REMOTE_IP" != "$EXPECTED_IP" ]; then
    printf '  [WARN] IP отличается от справочного (возможен CDN/прокси/шлюз).\n'
    WARN_COUNT=$((WARN_COUNT + 1))
  fi

  if [ "$AVAILABLE" = "yes" ]; then
    if [ "$ATTEMPT" -gt 1 ]; then
      printf '  [WARN] Ответ получен после повторной попытки; соединение было нестабильно.\n'
      WARN_COUNT=$((WARN_COUNT + 1))
    fi
    printf '  [OK] Ресурс доступен, прикладной HTTP-ответ получен.\n'
    OK_COUNT=$((OK_COUNT + 1))
  else
    case "$HTTP_CODE" in
      5??) printf '  [FAIL] Ресурс ответил ошибкой HTTP %s.\n' "$HTTP_CODE" ;;
      *) printf '  [FAIL] Прикладной HTTP-ответ не получен за %s попытки (код клиента %s).\n' "$ATTEMPT" "$CLIENT_RC" ;;
    esac
    if [ -s "$ERROR_FILE" ]; then
      printf '  Ошибка: '
      tail -n 2 "$ERROR_FILE" | tr '\n' ' '
      printf '\n'
    elif [ -s "$HEADER_FILE" ]; then
      printf '  Ошибка: '
      tail -n 2 "$HEADER_FILE" | tr '\n' ' '
      printf '\n'
    fi
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

check_gate() {
  GATE_OUTPUT=""
  if command -v ss >/dev/null 2>&1; then
    GATE_OUTPUT="$(ss -ntp 2>/dev/null)"
  elif command -v netstat >/dev/null 2>&1; then
    GATE_OUTPUT="$(netstat -ntp 2>/dev/null)"
  elif command -v busybox >/dev/null 2>&1 && busybox --list 2>/dev/null | grep -qx netstat; then
    GATE_OUTPUT="$(busybox netstat -ntp 2>/dev/null)"
  fi
  GATE_LINE="$(printf '%s\n' "$GATE_OUTPUT" | grep -E "$GATE_PATTERN" | head -n 1)"
  separator
  printf 'Cloud Gate: %s, порты 9088/9089\n' "$GATE_HOSTS"
  if [ -n "$GATE_LINE" ]; then
    printf '  [OK] Активное соединение найдено.\n'
    printf '  %s\n' "$GATE_LINE"
  else
    printf '  [WARN] Активное соединение не найдено. Это не отменяет результаты HTTP-проверки.\n'
    WARN_COUNT=$((WARN_COUNT + 1))
  fi
}

printf 'iRidi Cloud Check — %s\n' "$REGION"
printf 'Время запуска: %s\n' "$(date 2>/dev/null || echo unknown)"
printf 'Устройство: %s | %s | %s\n' "$(hostname 2>/dev/null || echo unknown)" "$(uname -s 2>/dev/null)" "$(uname -m 2>/dev/null)"
printf 'Метод: DNS + реальный HTTP(S) GET + анализ ответа и полезной нагрузки\n'

probe_resource www "Сайт и загрузки" "https://www.iridi.com/" "89.169.183.139" yes
probe_resource auth-ru "Авторизация RU" "https://auth.ru.iridi.com/" "84.201.152.245" yes
probe_resource endpoint "Облачная точка входа" "https://endpoint.iridi.com/" "95.181.182.182" yes
probe_resource bus77-home "Облако Bus77 Home" "https://bus77home.ru.iridi.com/" "84.201.152.245" yes
probe_resource iphub-home "Облако IP-Hub Home" "https://iphubhome.ru.iridi.com/" "37.139.42.137" yes
probe_resource commercial "Коммерческие предложения" "https://api.commercial-offer.iridi.com/" "213.219.212.191" yes
check_gate

separator
printf 'ИТОГ %s: проверено %s, доступно %s, ошибок %s, предупреждений %s\n' "$REGION" "$TOTAL" "$OK_COUNT" "$FAIL_COUNT" "$WARN_COUNT"
if [ "$FAIL_COUNT" -eq 0 ]; then
  printf 'РЕЗУЛЬТАТ: PASS — обязательные облачные HTTP-ресурсы доступны.\n'
  exit 0
fi
printf 'РЕЗУЛЬТАТ: FAIL — часть обязательных облачных HTTP-ресурсов недоступна.\n'
exit 1
