# iRidi Diagnostics Scripts

Автономные `sh`- и PowerShell-скрипты для быстрой диагностики серверов iRidi во
время удалённого подключения. Файлы не требуют установки Python. Linux-версии
работают с POSIX `sh`, включая BusyBox на HS Server; Windows-версии рассчитаны
на штатный Windows PowerShell.

## Скрипты

| Файл | Назначение |
| --- | --- |
| `check_i3knx.sh` | Прикладная проверка облачных ресурсов i3 KNX и активной Cloud Gate-сессии |
| `check_bus77_home.sh` | Прикладная проверка облачных ресурсов Bus77 Home |
| `check_bus77_lite.sh` | Прикладная проверка облачных ресурсов Bus77 Lite |
| `check_iridi_pro_ru.sh` | Проверка iRidi Pro Cloud для региона RU |
| `check_iridi_pro_eu.sh` | Проверка iRidi Pro Cloud для региона EU |
| `check_emmc_health.sh` | Состояние eMMC, ошибки ядра и безопасная проверка записи в корневой раздел |
| `check_iridi_cloud_windows_10_11.ps1` | Универсальная проверка облака с Windows 10/11 и PowerShell 5.1 |
| `check_iridi_cloud_windows_7.ps1` | Универсальная проверка облака с Windows 7 и PowerShell 2.0+ |

Облачные проверки выполняют DNS-разрешение и реальный HTTP(S) GET, показывают
фактический IP, HTTP-статус, тип и размер полезной нагрузки. При сетевой ошибке
без HTTP-ответа запрос повторяется до трёх раз. Ответы закрытых хранилищ `403`
считаются подтверждением доступности ресурса.

## Быстрый запуск

Замените имя файла в командах на нужный скрипт:

```sh
cd /tmp
curl -fsSLO https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/check_bus77_home.sh
sh check_bus77_home.sh 2>&1 | tee check_bus77_home.txt
```

Если на сервере нет `curl`:

```sh
cd /tmp
wget https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/check_bus77_home.sh
sh check_bus77_home.sh 2>&1 | tee check_bus77_home.txt
```

Для остальных продуктов:

```sh
sh check_i3knx.sh
sh check_bus77_lite.sh
sh check_iridi_pro_ru.sh
sh check_iridi_pro_eu.sh
```

## Windows 10 и Windows 11

Скачайте универсальный файл в PowerShell:

```powershell
Set-Location $env:TEMP
curl.exe -fL "https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/check_iridi_cloud_windows_10_11.ps1" -o "check_iridi_cloud_windows_10_11.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\check_iridi_cloud_windows_10_11.ps1 -Product bus77-home
```

Доступные значения `-Product`:

```powershell
-Product i3knx
-Product bus77-home
-Product bus77-lite
-Product iridi-pro -Region RU
-Product iridi-pro -Region EU
```

## Windows 7

Скачайте файл через браузер или из `cmd.exe` штатной утилитой Windows:

```bat
certutil.exe -urlcache -split -f "https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/check_iridi_cloud_windows_7.ps1" "%TEMP%\check_iridi_cloud_windows_7.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\check_iridi_cloud_windows_7.ps1" -Product bus77-home
```

Windows 7-версия совместима с синтаксисом PowerShell 2.0 и выполняет HTTPS GET
через встроенный WinHTTP с явным включением TLS 1.2. Если Windows 7 давно не
обновлялась и системный SChannel не поддерживает TLS 1.2, скрипт выведет
понятную ошибку соединения — это будет проблемой ОС, а не облачного ресурса.

Обе Windows-версии выполняют реальный HTTP(S) GET с чтением полезной нагрузки и
пытаются установить TCP-соединение с Cloud Gate на портах 9088/9089. Результат
можно сохранить стандартным `Tee-Object`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\check_iridi_cloud_windows_10_11.ps1 -Product i3knx 2>&1 | Tee-Object -FilePath .\iridi-cloud-report.txt
```

## Диагностика eMMC

Запускайте от `root`, чтобы выполнить контролируемую запись 1 МиБ в корень,
`sync`, два чтения с проверкой контрольной суммы и удаление временного файла:

```sh
sh check_emmc_health.sh 2>&1 | tee check_emmc_health.txt
```

Пассивная проверка без записи:

```sh
sh check_emmc_health.sh --no-write
```

Скрипт не пишет напрямую в блочное устройство, не запускает `fsck` и не
перемонтирует разделы. Результат `PASS` не исключает скрытую или периодическую
неисправность накопителя.

## Коды завершения

- облачные проверки: `0` — обязательные HTTP-ресурсы доступны, `1` — есть
  недоступные ресурсы;
- проверка eMMC: `0` — `PASS`, `1` — `WARN`, `2` — `FAIL`.

Cloud Gate проверяется по активной сессии процесса `iridium`. Запускайте
продуктовый скрипт на сервере с соответствующим установленным ПО, иначе найденная
сессия может относиться к другому продукту.
