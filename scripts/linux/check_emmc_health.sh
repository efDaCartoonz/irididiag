#!/bin/sh

# Безопасная диагностика eMMC на iRidi HS/ProAV/UMC и Linux-серверах.
# По умолчанию выполняет контролируемую запись 1 МиБ в корень, sync,
# повторное чтение с контрольной суммой и удаление временного файла.
# Вывод одновременно показывается на экране и сохраняется в отдельный лог.
#
# Запуск:       sh check_emmc_health.sh
# Без записи:   sh check_emmc_health.sh --no-write

# Portable logging wrapper. The diagnostic body runs as a child so BusyBox tee
# can show live output and save it without requiring Bash process substitution.
if [ "${IRIDI_EMMC_LOG_ACTIVE:-0}" != "1" ]; then
  CURRENT_DIRECTORY="$(pwd 2>/dev/null || printf '.')"
  LOG_DIRECTORY="${IRIDI_DIAG_LOG_DIR:-$CURRENT_DIRECTORY}"
  if [ ! -d "$LOG_DIRECTORY" ] || [ ! -w "$LOG_DIRECTORY" ]; then
    LOG_DIRECTORY="${TMPDIR:-/tmp}"
  fi
  HOST_LABEL="$(hostname 2>/dev/null || printf server)"
  HOST_LABEL="$(printf '%s' "$HOST_LABEL" | tr -c 'A-Za-z0-9._-' '_')"
  [ -n "$HOST_LABEL" ] || HOST_LABEL=server
  LOG_TIMESTAMP="$(date '+%Y%m%d_%H%M%S' 2>/dev/null || printf unknown_time)"
  LOG_FILE="$LOG_DIRECTORY/emmc_diagnostic_${HOST_LABEL}_${LOG_TIMESTAMP}_$$.log"
  export IRIDI_EMMC_LOG_ACTIVE=1
  export IRIDI_EMMC_LOG_FILE="$LOG_FILE"

  if command -v tee >/dev/null 2>&1; then
    sh "$0" "$@" 2>&1 | tee "$LOG_FILE"
    TEE_RC=$?
    RESULT_LINE="$(grep '^РЕЗУЛЬТАТ:' "$LOG_FILE" 2>/dev/null | tail -n 1)"
    case "$RESULT_LINE" in
      *PASS*) FINAL_RC=0 ;;
      *WARN*) FINAL_RC=1 ;;
      *FAIL*) FINAL_RC=2 ;;
      *) FINAL_RC=2 ;;
    esac
    if [ "$TEE_RC" -ne 0 ]; then
      FINAL_RC=2
      printf '[FAIL] Не удалось полностью записать лог-файл.\n'
    fi
    printf '\nЛог сохранён: %s\n' "$LOG_FILE" | tee -a "$LOG_FILE"
    exit "$FINAL_RC"
  fi

  sh "$0" "$@" >"$LOG_FILE" 2>&1
  FINAL_RC=$?
  cat "$LOG_FILE"
  printf '\nЛог сохранён: %s\n' "$LOG_FILE"
  exit "$FINAL_RC"
fi

set +e
export LC_ALL=C

SCRIPT_VERSION=1.1

WRITE_TEST=yes
[ "${1:-}" = "--no-write" ] && WRITE_TEST=no

WARNINGS=0
FAILURES=0
TEST_FILE=""
TEST_ERROR=""
EMMC_STATUS="не обнаружена"
BLOCK_STATUS="не определён"
WEAR_STATUS="недоступны"
KERNEL_STATUS="не проверен"
ROOT_WRITE_STATUS="не выполнена"

cleanup() {
  [ -n "$TEST_FILE" ] && rm -f "$TEST_FILE"
  [ -n "$TEST_ERROR" ] && rm -f "$TEST_ERROR"
}
trap cleanup EXIT HUP INT TERM

separator() {
  printf '%s\n' '----------------------------------------------------------------'
}

ok() {
  printf '  [OK] %s\n' "$1"
}

warn() {
  WARNINGS=$((WARNINGS + 1))
  printf '  [WARN] %s\n' "$1"
}

fail() {
  FAILURES=$((FAILURES + 1))
  printf '  [FAIL] %s\n' "$1"
}

read_field() {
  if [ -r "$1" ]; then
    cat "$1" 2>/dev/null
  fi
}

normalize_hex() {
  printf '%s' "$1" | tr 'A-F' 'a-f'
}

manufacturer_name() {
  case "$(normalize_hex "$1")" in
    0x000015|0x15) printf 'Samsung' ;;
    0x000013|0x13) printf 'Micron' ;;
    0x000045|0x45) printf 'SanDisk/Western Digital' ;;
    0x000090|0x90) printf 'SK hynix' ;;
    0x000011|0x11) printf 'Kioxia/Toshiba' ;;
    *) printf 'не определён' ;;
  esac
}

life_description() {
  case "$(normalize_hex "$1")" in
    0x00) printf 'оценка не определена' ;;
    0x01) printf 'использовано 0–10%% ресурса' ;;
    0x02) printf 'использовано 10–20%% ресурса' ;;
    0x03) printf 'использовано 20–30%% ресурса' ;;
    0x04) printf 'использовано 30–40%% ресурса' ;;
    0x05) printf 'использовано 40–50%% ресурса' ;;
    0x06) printf 'использовано 50–60%% ресурса' ;;
    0x07) printf 'использовано 60–70%% ресурса' ;;
    0x08) printf 'использовано 70–80%% ресурса' ;;
    0x09) printf 'использовано 80–90%% ресурса' ;;
    0x0a) printf 'использовано 90–100%% ресурса' ;;
    0x0b) printf 'расчётный ресурс превышен' ;;
    *) printf 'неизвестное значение' ;;
  esac
}

pre_eol_description() {
  case "$(normalize_hex "$1")" in
    0x01) printf 'норма' ;;
    0x02) printf 'предупреждение: резервные блоки расходуются' ;;
    0x03) printf 'критическое состояние: резервные блоки исчерпаны' ;;
    *) printf 'не определено' ;;
  esac
}

checksum_file() {
  if command -v cksum >/dev/null 2>&1; then
    cksum "$1" 2>/dev/null | awk '{print $1":"$2}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" 2>/dev/null | awk '{print $1}'
  elif command -v md5sum >/dev/null 2>&1; then
    md5sum "$1" 2>/dev/null | awk '{print $1}'
  fi
}

printf 'Диагностика eMMC / корневого накопителя\n'
printf 'Версия скрипта: %s\n' "$SCRIPT_VERSION"
printf 'Время: %s\n' "$(date 2>/dev/null || echo unknown)"
printf 'Устройство: %s\n' "$(hostname 2>/dev/null || echo unknown)"
printf 'Лог-файл: %s\n' "${IRIDI_EMMC_LOG_FILE:-не задан}"
printf 'Модель платформы: %s\n' "$(tr -d '\000' </proc/device-tree/model 2>/dev/null || echo unknown)"
printf 'Ядро: %s\n' "$(uname -a 2>/dev/null)"
printf 'Режим проверки записи: %s\n' "$WRITE_TEST"

separator
printf '1. eMMC и аппаратные показатели износа\n'

MMC_DEVICE=""
for candidate in /sys/bus/mmc/devices/*; do
  [ -d "$candidate" ] || continue
  [ "$(read_field "$candidate/type")" = "MMC" ] || continue
  MMC_DEVICE="$candidate"
  break
done

MMC_BLOCK=""
MMC_NODE=""
if [ -n "$MMC_DEVICE" ]; then
  for candidate in "$MMC_DEVICE"/block/mmcblk*; do
    [ -e "$candidate" ] || continue
    MMC_BLOCK="$candidate"
    MMC_NODE="/dev/${candidate##*/}"
    break
  done
fi

if [ -z "$MMC_DEVICE" ]; then
  fail "eMMC не обнаружена в /sys/bus/mmc/devices."
else
  EMMC_STATUS="обнаружена"
  MMC_NAME="$(read_field "$MMC_DEVICE/name")"
  MMC_MANFID="$(read_field "$MMC_DEVICE/manfid")"
  MMC_DATE="$(read_field "$MMC_DEVICE/date")"
  MMC_SERIAL="$(read_field "$MMC_DEVICE/serial")"
  MMC_LIFE="$(read_field "$MMC_DEVICE/life_time")"
  MMC_LIFE_A="$(printf '%s' "$MMC_LIFE" | awk '{print $1}')"
  MMC_LIFE_B="$(printf '%s' "$MMC_LIFE" | awk '{print $2}')"
  MMC_PRE_EOL="$(read_field "$MMC_DEVICE/pre_eol_info")"
  if [ -n "$MMC_LIFE_A" ] || [ -n "$MMC_LIFE_B" ] || [ -n "$MMC_PRE_EOL" ]; then
    WEAR_STATUS="частично доступны через sysfs"
  fi
  printf '  Sysfs-устройство: %s\n' "${MMC_DEVICE##*/}"
  printf '  Блочное устройство: %s\n' "${MMC_NODE:-не определено}"
  printf '  Модель eMMC: %s\n' "${MMC_NAME:-не определена}"
  printf '  Производитель: %s (%s)\n' "$(manufacturer_name "$MMC_MANFID")" "${MMC_MANFID:-нет данных}"
  printf '  Дата выпуска: %s\n' "${MMC_DATE:-нет данных}"
  printf '  Серийный номер: %s\n' "${MMC_SERIAL:-нет данных}"
  printf '  LIFE_TIME A: %s — %s\n' "${MMC_LIFE_A:-нет данных}" "$(life_description "$MMC_LIFE_A")"
  printf '  LIFE_TIME B: %s — %s\n' "${MMC_LIFE_B:-нет данных}" "$(life_description "$MMC_LIFE_B")"
  printf '  PRE_EOL_INFO: %s — %s\n' "${MMC_PRE_EOL:-нет данных}" "$(pre_eol_description "$MMC_PRE_EOL")"

  case "$(normalize_hex "$MMC_PRE_EOL")" in
    0x01) ok "PRE_EOL_INFO в норме." ;;
    0x02) warn "PRE_EOL_INFO сообщает о расходовании резервных блоков." ;;
    0x03) fail "PRE_EOL_INFO сообщает о критическом состоянии eMMC." ;;
    *) warn "PRE_EOL_INFO недоступен или не распознан." ;;
  esac
  for value in "$MMC_LIFE_A" "$MMC_LIFE_B"; do
    case "$(normalize_hex "$value")" in
      0x09|0x0a) warn "Один из счётчиков LIFE_TIME показывает не менее 80% использованного ресурса." ;;
      0x0b) fail "Один из счётчиков LIFE_TIME сообщает о превышении расчётного ресурса." ;;
    esac
  done
fi

BLOCK_RO=""
if [ -n "$MMC_BLOCK" ]; then
  BLOCK_RO="$(read_field "$MMC_BLOCK/ro")"
  printf '  Флаг read-only основного блока: %s\n' "${BLOCK_RO:-не определён}"
  case "$BLOCK_RO" in
    0) BLOCK_STATUS="доступен для записи"; ok "Основной пользовательский блок eMMC доступен для записи на уровне ядра." ;;
    1) BLOCK_STATUS="read-only"; fail "Основной пользовательский блок eMMC отмечен ядром как read-only." ;;
    *) warn "Не удалось прочитать флаг read-only основного блока." ;;
  esac
fi
printf '  Примечание: mmcblk*boot0/boot1 обычно имеют ro=1 — для загрузочных областей это штатно.\n'

USER_WP=""
if command -v mmc >/dev/null 2>&1 && [ -b "$MMC_NODE" ]; then
  EXT_CSD="$(mmc extcsd read "$MMC_NODE" 2>&1)"
  USER_WP="$(printf '%s\n' "$EXT_CSD" | awk -F': ' '/User area write protection register \[USER_WP\]/{print $2; exit}')"
  EXT_LIFE_A="$(printf '%s\n' "$EXT_CSD" | awk -F': ' '/EXT_CSD_DEVICE_LIFE_TIME_EST_TYP_A/{print $2; exit}')"
  EXT_LIFE_B="$(printf '%s\n' "$EXT_CSD" | awk -F': ' '/EXT_CSD_DEVICE_LIFE_TIME_EST_TYP_B/{print $2; exit}')"
  EXT_PRE_EOL="$(printf '%s\n' "$EXT_CSD" | awk -F': ' '/EXT_CSD_PRE_EOL_INFO/{print $2; exit}')"
  if [ -n "$EXT_LIFE_A" ] || [ -n "$EXT_LIFE_B" ] || [ -n "$EXT_PRE_EOL" ]; then
    WEAR_STATUS="доступны через EXT_CSD"
  fi
  printf '  EXT_CSD USER_WP: %s\n' "${USER_WP:-не определён}"
  printf '  EXT_CSD LIFE_TIME A/B: %s / %s\n' "${EXT_LIFE_A:-не определён}" "${EXT_LIFE_B:-не определён}"
  printf '  EXT_CSD PRE_EOL: %s\n' "${EXT_PRE_EOL:-не определён}"
  case "$(normalize_hex "$USER_WP")" in
    0x00) ok "USER_WP=0x00: защита пользовательской области от записи не включена." ;;
    "") warn "Не удалось прочитать USER_WP из EXT_CSD." ;;
    *) warn "USER_WP имеет ненулевое значение; требуется расшифровка битов защиты." ;;
  esac
else
  warn "Утилита mmc отсутствует; используются доступные поля sysfs."
fi

separator
printf '2. Корневая файловая система\n'
ROOT_SOURCE="$(awk '$2=="/" {print $1; exit}' /proc/mounts 2>/dev/null)"
ROOT_FS="$(awk '$2=="/" {print $3; exit}' /proc/mounts 2>/dev/null)"
ROOT_OPTIONS="$(awk '$2=="/" {print $4; exit}' /proc/mounts 2>/dev/null)"
ROOT_REAL_SOURCE="$(mount 2>/dev/null | awk '$2=="on" && $3=="/" {print $1; exit}')"
printf '  Источник: %s\n' "${ROOT_REAL_SOURCE:-${ROOT_SOURCE:-не определён}}"
printf '  Файловая система: %s\n' "${ROOT_FS:-не определена}"
printf '  Параметры: %s\n' "${ROOT_OPTIONS:-не определены}"
df -h / 2>/dev/null | sed 's/^/  /'
case ",${ROOT_OPTIONS}," in
  *,rw,*) ROOT_RW=yes; ok "Корень смонтирован в режиме rw." ;;
  *) ROOT_RW=no; fail "Корень не смонтирован в режиме rw." ;;
esac

separator
printf '3. Ошибки ядра с момента загрузки\n'
KERNEL_PATTERN='buffer i/o error|blk_update.*i/o error|print_req_error.*i/o error|i/o error.*mmcblk|ext4-fs.*error|remounting filesystem read-only|mmc.*(timed out|timeout|i/o error)|filesystem error|journal.*abort'
KERNEL_ERRORS="$(dmesg 2>/dev/null | grep -Ei "$KERNEL_PATTERN")"
KERNEL_ERROR_COUNT="$(printf '%s\n' "$KERNEL_ERRORS" | sed '/^$/d' | wc -l | tr -d ' ')"
printf '  Найдено критических строк: %s\n' "${KERNEL_ERROR_COUNT:-0}"
if [ "${KERNEL_ERROR_COUNT:-0}" -gt 0 ] 2>/dev/null; then
  KERNEL_STATUS="найдены ошибки"
  printf '%s\n' "$KERNEL_ERRORS" | tail -n 60 | sed 's/^/  /'
  fail "В журнале ядра есть признаки ошибок накопителя или файловой системы."
else
  KERNEL_STATUS="ошибок не найдено"
  ok "Критические I/O, timeout и EXT4-ошибки не найдены."
fi

separator
printf '4. Контролируемая запись в корневой раздел\n'
if [ "$WRITE_TEST" != "yes" ]; then
  ROOT_WRITE_STATUS="пропущена (--no-write)"
  printf '  [SKIP] Тест отключён параметром --no-write.\n'
elif [ "$ROOT_RW" != "yes" ]; then
  ROOT_WRITE_STATUS="невозможна: корень не rw"
  fail "Тест записи невозможен: корень не в режиме rw."
else
  FREE_KB="$(df -Pk / 2>/dev/null | awk 'NR==2 {print $4}')"
  printf '  Свободно до теста: %s КиБ\n' "${FREE_KB:-не определено}"
  if [ "${FREE_KB:-0}" -lt 4096 ] 2>/dev/null; then
    ROOT_WRITE_STATUS="пропущена: мало места"
    fail "Менее 4 МиБ свободного места; тест записи пропущен."
  else
    TEST_FILE="/server-diag-emmc-test-$$.bin"
    TEST_ERROR="${TMPDIR:-/tmp}/server-diag-emmc-test-$$.err"
    umask 077
    printf '  Временный файл: %s\n' "$TEST_FILE"
    dd if=/dev/urandom of="$TEST_FILE" bs=4096 count=256 2>"$TEST_ERROR"
    WRITE_RC=$?
    sync
    if [ "$WRITE_RC" -eq 0 ] && [ -f "$TEST_FILE" ]; then
      WRITTEN_SIZE="$(wc -c <"$TEST_FILE" | tr -d ' ')"
      CHECKSUM_1="$(checksum_file "$TEST_FILE")"
      CHECKSUM_2="$(checksum_file "$TEST_FILE")"
      printf '  Записано: %s байт\n' "${WRITTEN_SIZE:-0}"
      printf '  Контрольная сумма после sync: %s\n' "${CHECKSUM_1:-недоступна}"
      printf '  Контрольная сумма повторного чтения: %s\n' "${CHECKSUM_2:-недоступна}"
      if [ "$WRITTEN_SIZE" = "1048576" ] && [ -n "$CHECKSUM_1" ] && [ "$CHECKSUM_1" = "$CHECKSUM_2" ]; then
        ROOT_WRITE_STATUS="успешна"
        ok "Запись 1 МиБ, sync и повторное чтение прошли успешно."
      else
        ROOT_WRITE_STATUS="ошибка проверки"
        fail "Размер или контрольная сумма после записи не совпали."
      fi
    else
      ROOT_WRITE_STATUS="ошибка записи"
      WRITE_ERROR_TEXT="$(tail -n 3 "$TEST_ERROR" 2>/dev/null | tr '\n' ' ')"
      fail "Запись в корень завершилась ошибкой: ${WRITE_ERROR_TEXT:-неизвестная ошибка}"
    fi
    rm -f "$TEST_FILE" "$TEST_ERROR"
    sync
    if [ -e "$TEST_FILE" ]; then
      fail "Не удалось удалить временный тестовый файл."
    else
      ok "Временный файл удалён."
      TEST_FILE=""
      TEST_ERROR=""
    fi
  fi
fi

separator
printf 'КРАТКИЙ ИТОГ\n'
printf '  eMMC: %s\n' "$EMMC_STATUS"
printf '  Основной блок: %s\n' "$BLOCK_STATUS"
printf '  Показатели износа: %s\n' "$WEAR_STATUS"
printf '  Ошибки ядра: %s\n' "$KERNEL_STATUS"
printf '  Проверка записи в /: %s\n' "$ROOT_WRITE_STATUS"
if [ "$FAILURES" -eq 0 ] && [ "$ROOT_WRITE_STATUS" = "успешна" ] && [ "$KERNEL_STATUS" = "ошибок не найдено" ]; then
  printf '  Вывод: текущая запись и чтение работают; критических ошибок не обнаружено.\n'
  if [ "$WEAR_STATUS" = "недоступны" ]; then
    printf '  Ограничение: остаточный ресурс eMMC этой прошивкой не определяется.\n'
  fi
elif [ "$FAILURES" -gt 0 ]; then
  printf '  Вывод: обнаружена ошибка; накопитель или файловая система требуют анализа.\n'
else
  printf '  Вывод: проверка выполнена частично; смотрите предупреждения выше.\n'
fi

separator
printf 'ИТОГ: ошибок %s, предупреждений %s\n' "$FAILURES" "$WARNINGS"
if [ "$FAILURES" -gt 0 ]; then
  printf 'РЕЗУЛЬТАТ: FAIL — есть признаки неисправности или невозможности записи.\n'
  exit 2
fi
if [ "$WARNINGS" -gt 0 ]; then
  printf 'РЕЗУЛЬТАТ: WARN — критических ошибок нет, но часть данных требует внимания.\n'
  exit 1
fi
printf 'РЕЗУЛЬТАТ: PASS — доступные показатели eMMC в норме, ошибок ядра нет, запись работает.\n'
printf 'Важно: тест файла не заменяет длительный тест памяти и не доказывает отсутствие скрытых дефектов.\n'
exit 0
