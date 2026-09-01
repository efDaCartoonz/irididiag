# iRidi Diagnostics Scripts

Автономные `sh`- и PowerShell-скрипты для быстрой диагностики серверов iRidi во
время удалённого подключения. Файлы не требуют установки Python. Linux-версии
работают с POSIX `sh`, включая BusyBox на HS Server; Windows-версии рассчитаны
на штатный Windows PowerShell.

## Структура архива

- `scripts/windows` — запуск с клиентского компьютера Windows;
- `scripts/linux` — запуск на Linux, Debian и прошивках BusyBox.

### Windows

| Файл | Назначение |
| --- | --- |
| `check_iridi_cloud_windows_10_11.ps1` | Универсальная проверка облака с Windows 10/11 и PowerShell 5.1 |
| `check_iridi_cloud_windows_7.ps1` | Универсальная проверка облака с Windows 7 и PowerShell 2.0+ |
| `run_iridi_cloud_windows.cmd` | Простой запуск Windows: выбор продукта в меню и автоматический лог |

### Linux и BusyBox

| Файл | Назначение |
| --- | --- |
| `check_i3knx.sh` | Прикладная проверка облачных ресурсов i3 KNX и активной Cloud Gate-сессии |
| `check_bus77_home.sh` | Прикладная проверка облачных ресурсов Bus77 Home |
| `check_bus77_lite.sh` | Прикладная проверка облачных ресурсов Bus77 Lite |
| `check_iridi_pro_ru.sh` | Проверка iRidi Pro Cloud для региона RU |
| `check_iridi_pro_eu.sh` | Проверка iRidi Pro Cloud для региона EU |
| `check_emmc_health.sh` | Состояние eMMC, проверка записи и автоматический лог для отправки инженеру |

Облачные проверки выполняют DNS-разрешение и реальный HTTP(S) GET, показывают
фактический IP, HTTP-статус, тип и размер полезной нагрузки. При сетевой ошибке
без HTTP-ответа запрос повторяется до трёх раз. Ответы закрытых хранилищ `403`
считаются подтверждением доступности ресурса.

## Быстрый запуск

Замените имя файла в командах на нужный скрипт:

```sh
cd /tmp
curl -fsSLO https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/linux/check_bus77_home.sh
sh check_bus77_home.sh 2>&1 | tee check_bus77_home.txt
```

Если на сервере нет `curl`:

```sh
cd /tmp
wget https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/linux/check_bus77_home.sh
sh check_bus77_home.sh 2>&1 | tee check_bus77_home.txt
```

Для остальных продуктов:

```sh
sh check_i3knx.sh
sh check_bus77_lite.sh
sh check_iridi_pro_ru.sh
sh check_iridi_pro_eu.sh
```

## Простой запуск в Windows

1. Скачайте [ZIP-архив репозитория](https://github.com/efDaCartoonz/irididiag/archive/refs/heads/main.zip).
2. Полностью распакуйте архив.
3. Откройте каталог `scripts\windows` и дважды нажмите
   `run_iridi_cloud_windows.cmd`.
4. Выберите цифрой нужный продукт: i3 KNX, Bus77 Home, Bus77 Lite, iRidi Pro RU
   или iRidi Pro EU.

В окне виден ход проверки каждого ресурса. После завершения окно остаётся
открытым, а полный результат сохраняется в `scripts\windows\logs`. Для каждого
запуска создаётся отдельный файл с продуктом, регионом и временем в имени, например
`iridi_pro_eu_20260901_143000.log`. Лаунчер сам определяет версию PowerShell и
выбирает совместимый сценарий для Windows 7 или Windows 10/11.

## Windows 10 и Windows 11: запуск для инженера

Скачайте универсальный файл в PowerShell:

```powershell
Set-Location $env:TEMP
curl.exe -fL "https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/windows/check_iridi_cloud_windows_10_11.ps1" -o "check_iridi_cloud_windows_10_11.ps1"
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

## Windows 7: запуск для инженера

Скачайте файл через браузер или из `cmd.exe` штатной утилитой Windows:

```bat
certutil.exe -urlcache -split -f "https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/windows/check_iridi_cloud_windows_7.ps1" "%TEMP%\check_iridi_cloud_windows_7.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\check_iridi_cloud_windows_7.ps1" -Product bus77-home
```

Windows 7-версия совместима с синтаксисом PowerShell 2.0 и выполняет HTTPS GET
через встроенный WinHTTP с явным включением TLS 1.2. Если Windows 7 давно не
обновлялась и системный SChannel не поддерживает TLS 1.2, скрипт выведет
понятную ошибку соединения — это будет проблемой ОС, а не облачного ресурса.

Обе Windows-версии выполняют реальный HTTP(S) GET с чтением полезной нагрузки и
пытаются установить TCP-соединение с Cloud Gate на портах 9088/9089. При любом
запуске результат автоматически сохраняется в подкаталог `logs` рядом со
скриптом. При необходимости инженер также может создать вторую копию через
`Tee-Object`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\check_iridi_cloud_windows_10_11.ps1 -Product i3knx 2>&1 | Tee-Object -FilePath .\iridi-cloud-report.txt
```

## Диагностика eMMC

Пользователю достаточно перейти в каталог со скриптом и запустить его от
`root`:

```sh
sh check_emmc_health.sh
```

Если сервер имеет доступ к GitHub, скачать и запустить актуальную версию можно
тремя командами:

```sh
cd /tmp
wget https://raw.githubusercontent.com/efDaCartoonz/irididiag/main/scripts/linux/check_emmc_health.sh
sh check_emmc_health.sh
```

Ход проверки виден в терминале. Одновременно в текущем каталоге автоматически
создаётся отдельный файл вида
`emmc_diagnostic_ИМЯ-СЕРВЕРА_ГГГГММДД_ЧЧММСС_PID.log`. После завершения
пользователю достаточно передать этот файл инженеру.

Скрипт определяет eMMC и флаг read-only, ищет ошибки накопителя в журнале ядра,
записывает 1 МиБ непосредственно в `/`, выполняет `sync`, дважды читает файл и
сравнивает контрольные суммы. Тестовый файл автоматически удаляется.

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
