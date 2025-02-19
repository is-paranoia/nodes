#!/bin/bash

# 1. Проверка установки screen и его установка (Linux: apt-get, macOS: brew)
if ! command -v screen >/dev/null 2>&1; then
  echo "screen не установлен. Выполняется установка..."
  OS_TMP=$(uname)
  if [ "$OS_TMP" = "Linux" ]; then
    sudo apt-get update && sudo apt-get install screen -y
  elif [ "$OS_TMP" = "Darwin" ]; then
    echo "В macOS screen обычно установлен по умолчанию. Если он отсутствует, установите его с помощью brew."
    brew install screen
  fi
fi

# 2. Проверка, выполняется ли скрипт в сеансе screen (если нет, создается сеанс hyperlane_node и выполняется автоматическое подключение)
if [ -z "$STY" ]; then
  echo "Скрипт не выполняется в сеансе screen."
  echo "Создается сеанс screen с именем hyperlane_node и выполняется автоматическое подключение..."
  exec screen -S hyperlane_node -D -R "$SHELL" -c "$0; exec $SHELL"
fi

# 3. Ввод пользователя: имя валидатора и RPC URL базовой сети
read -p "Введите имя валидатора: " VALIDATOR_NAME
read -p "Введите RPC URL базовой сети: " RPC_CHAIN

echo "----------------------------------------------"
echo "Запуск скрипта автоматической настройки узла Hyperlane"
echo "Перед продолжением убедитесь в следующем:"
echo "  - Сохраните приватный ключ создаваемого кошелька в безопасном месте"
echo "  - Проверьте, что на кошельке достаточно ETH для комиссий в сети Base"
echo "----------------------------------------------"
echo ""

# Определение ОС и соответствующие команды
OS=$(uname)

if [ "$OS" = "Linux" ]; then
  echo "Обнаружена среда Linux. Выполняются команды для Linux..."
  
  sudo apt-get update && sudo apt-get upgrade -y
  sudo apt-get install docker.io -y
  
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash
  
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  
  nvm install 20
  
  # Установка и обновление Foundry
  curl -L https://foundry.paradigm.xyz | bash
  # Подключение профиля пользователя (если не root, используется $HOME)
  if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
  else
    source "$HOME/.profile"
  fi
  export PATH="$HOME/.foundry/bin:$PATH"
  foundryup
  
  # Создание нового кошелька и сохранение в файл hyperlane_wallet
  echo "Создание нового кошелька..."
  cast wallet new | tee hyperlane_wallet
  
  # Извлечение приватного ключа из файла hyperlane_wallet
  WALLET_OUTPUT=$(cat hyperlane_wallet)
  PRIVATE_KEY=$(echo "$WALLET_OUTPUT" | grep -i "Private key:" | awk -F': ' '{print $2}')
  echo "Извлеченный приватный ключ: $PRIVATE_KEY"
  echo ""
  
  # Установка Hyperlane CLI
  npm install -g @hyperlane-xyz/cli
  
  docker pull --platform linux/amd64 gcr.io/abacus-labs-dev/hyperlane-agent:agents-v1.0.0
  
  mkdir -p /root/hyperlane_db_base && chmod -R 777 /root/hyperlane_db_base
  
  docker run -d \
    -it \
    --name hyperlane \
    --mount type=bind,source=/root/hyperlane_db_base,target=/hyperlane_db_base \
    gcr.io/abacus-labs-dev/hyperlane-agent:agents-v1.0.0 \
    ./validator \
    --db /hyperlane_db_base \
    --originChainName base \
    --reorgPeriod 1 \
    --validator.id "$VALIDATOR_NAME" \
    --checkpointSyncer.type localStorage \
    --checkpointSyncer.folder base \
    --checkpointSyncer.path /hyperlane_db_base/base_checkpoints \
    --validator.key "$PRIVATE_KEY" \
    --chains.base.signer.key "$PRIVATE_KEY" \
    --chains.base.customRpcUrls "$RPC_CHAIN"
  
else
  echo "Операционная система не поддерживается: $OS"
  exit 1
fi

echo ""
echo "----------------------------------------------"
echo "Установка завершена."
echo "Используйте команду cat hyperlane_wallet, чтобы проверить адрес кошелька, а затем отправьте ETH для комиссии в сети Base."
echo "Для просмотра логов контейнера Hyperlane выполните команду:"
echo "  docker logs -f hyperlane"
echo "Также проверьте транзакции по созданному кошельку на https://basescan.org/."
echo "----------------------------------------------"
