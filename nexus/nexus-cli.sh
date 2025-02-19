#!/usr/bin/env bash

SESSION_NAME="nexus_node_setup"

##################################
# 0. Проверка дублирования screen-сессии
##################################
screen -list | grep -q "$SESSION_NAME"
if [ $? -eq 0 ]; then
  echo "[Уведомление] Screen-сессия '$SESSION_NAME' уже существует. Подключаемся..."
  exec screen -r "$SESSION_NAME"
fi

##################################
# 1. Создание новой screen-сессии
##################################
echo "[Уведомление] Создаем новую screen-сессию '$SESSION_NAME' и начинаем настройку Nexus Node..."

screen -S "$SESSION_NAME" -m bash -c '
    ##################################
    # (A) Проверка окружения (предполагается Ubuntu)
    ##################################
    OS=$(uname -s)
    if [ "$OS" != "Linux" ]; then
        echo "[Ошибка] Этот скрипт предназначен только для Linux (Ubuntu)."
        exit 1
    fi

    # Простая проверка на Ubuntu через /etc/os-release (опционально)
    if [ -f /etc/os-release ]; then
      . /etc/os-release
      if [[ "$ID" != "ubuntu" && "$ID_LIKE" != *"ubuntu"* ]]; then
        echo "[Предупреждение] Похоже, это не Ubuntu-подобная система. Команда apt может не работать."
      fi
    fi

    ##################################
    # (B) Подготовка (установка пакетов)
    ##################################
    echo "[Шаг] Обновление и апгрейд apt"
    sudo apt update && sudo apt upgrade -y

    echo "[Шаг] Установка необходимых пакетов (build-essential, pkg-config и т.д.)"
    sudo apt install -y build-essential pkg-config libssl-dev git-all curl screen unzip protobuf-compiler

    ##################################
    # (C) Установка Rust/Cargo
    ##################################
    echo "[Шаг] Установка Rust (rustup)"
    curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # *** Загрузка .cargo/env сразу после установки Rust (актуально для текущей оболочки)
    if [ -f "$HOME/.cargo/env" ]; then
      . "$HOME/.cargo/env"
    fi

    echo "[Проверка] Версия cargo:"
    cargo --version || {
      echo "[Ошибка] Команда cargo не найдена. Похоже, ~/.cargo/env не был загружен."
      exit 1
    }

    rustup target add riscv32i-unknown-none-elf

    echo "Ручная установка protobuf"
    https://github.com/protocolbuffers/protobuf/releases/download/v25.6/protoc-25.6-linux-x86_64.zip
    unzip protoc-25.6-linux-x86_64.zip
    mv bin/protoc /usr/local/bin

    ##################################
    # (D) Установка Nexus CLI
    ##################################
    echo "[Шаг] Установка Nexus CLI (curl https://cli.nexus.xyz/ | sh)"
    curl https://cli.nexus.xyz/ | sh

    echo
    echo "=== Установка Nexus Node завершена. ==="
    echo

    ##################################
    # (E) Настройка Prover ID (на русском)
    ##################################
    cat <<EOF
[Уведомление] При запуске или первой настройке Nexus Node вам будет предложено настроить Prover ID.

1) Связка с веб-аккаунтом (рекомендуется):
   - На сайте beta.nexus.xyz (после входа) найдите свой “Prover ID”,
   - При запуске Node введите этот ID.
   - Это позволит связать ваши действия в CLI с вашим веб-аккаунтом для удобного управления.

2) Генерация случайного ID:
   - Если вы пропустите ввод Prover ID, будет создан случайный ID.
   - Однако, если позже вы захотите связать его с веб-аккаунтом, вам придется зарегистрировать новый ID.

[Внимание] При использовании веб-браузера:
 - Если вы используете “режим инкогнито” или “приватное окно”, сохранение куки/сессий может быть ограничено.
 - Если вы явно запретили сохранение данных сайта в настройках браузера,
 - Если браузер настроен на регулярное удаление куки,
 - Если у вас активированы расширения браузера, которые выполняют такие действия,

В таких условиях информация о Prover ID, сохраненная в веб-аккаунте, может не загружаться корректно.
Для нормальной работы этой функции войдите в систему в обычном окне или разрешите сохранение куки/хранилища.

EOF

    echo "Все готово."
    echo "Когда появится запрос на ввод Prover ID, следуйте инструкциям выше."

    ##################################
    # (F) Предотвращение завершения сессии: сохранение оболочки
    ##################################
    echo "[Уведомление] Установка завершена. Screen-сессия не будет закрыта, оболочка останется активной."
    echo "Для завершения скрипта введите exit."
    exec bash
'

##################################
# 2. Автоматическое подключение к созданной сессии (attach)
##################################
echo "[Уведомление] Screen-сессия '$SESSION_NAME' создана. Подключаемся..."
exec screen -r "$SESSION_NAME"