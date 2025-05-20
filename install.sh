#!/bin/bash

# Получаем информацию о пользователе
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" = "root" ]; then
    echo "⚠️ Не рекомендуется запускать скрипт от имени root"
    echo "🔧 Для безопасности используйте обычного пользователя с sudo-привилегиями"
fi

# Проверка наличия необходимых утилит
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 не установлен!"
    echo "🔧 Попробуйте установить его с помощью: sudo apt update && sudo apt install python3"
    exit 1
fi

if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 не установлен!"
    echo "🔧 Попробуйте установить его с помощью: sudo apt install python3-pip"
    exit 1
fi

# Проверка наличия модуля venv
if ! python3 -c "import venv" &> /dev/null; then
    echo "❌ Модуль venv не доступен!"
    echo "🔧 Установите его с помощью: sudo apt install python3-venv"
    exit 1
fi

# Определяем директории (явно указываем домашнюю директорию пользователя)
HOME_DIR="/home/$CURRENT_USER"
PROJECT_DIR="$HOME_DIR/Silero-REST-Service"
VENV_PATH="$PROJECT_DIR/venv"

# Отладочная информация
echo "🔍 Текущий пользователь: $CURRENT_USER"
echo "📁 Домашняя директория: $HOME_DIR"
echo "📁 Проект будет установлен в: $PROJECT_DIR"

# Удаляем старое виртуальное окружение (если существует)
echo "🗑️ Удаляем предыдущее виртуальное окружение (если существует)..."
rm -rf "$VENV_PATH"

# Создаем директорию проекта
mkdir -p "$PROJECT_DIR"

# Переходим в директорию проекта
cd "$PROJECT_DIR" || { echo "❌ Не могу перейти в директорию $PROJECT_DIR"; exit 1; }

# Создаем виртуальное окружение
echo "🛠️ Создаем виртуальное окружение..."
if ! python3 -m venv "$VENV_PATH"; then
    echo "❌ Ошибка при создании виртуального окружения!"
    echo "🔧 Проверьте права доступа в $PROJECT_DIR"
    exit 1
fi

# Проверяем, существует ли виртуальное окружение
if [ ! -d "$VENV_PATH" ]; then
    echo "❌ Виртуальное окружение не создано!"
    echo "🔧 Проверьте свободное место на диске и права доступа"
    exit 1
fi

# Активируем виртуальное окружение
source "$VENV_PATH/bin/activate" || { echo "❌ Не могу активировать виртуальное окружение"; exit 1; }

# Обновляем pip
echo "🔧 Обновляем pip..."
pip install --upgrade pip || { echo "❌ Ошибка при обновлении pip"; exit 1; }

# Устанавливаем зависимости
echo "📦 Устанавливаем зависимости..."
pip install fastapi uvicorn torch ruaccent num2words || { echo "❌ Ошибка при установке зависимостей"; exit 1; }

echo "✅ Виртуальное окружение успешно создано в $VENV_PATH"

# Создаем systemd сервис
echo "⚙️ Настраиваем systemd сервис..."
SERVICE_NAME="silero_rest_service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME.service"

sudo tee "$SERVICE_PATH" > /dev/null <<EOL
[Unit]
Description=Silero REST Service
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$VENV_PATH/bin/uvicorn silero_rest_service:app --host 0.0.0.0 --port 5010
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Проверяем, успешно ли создан сервис
if [ ! -f "$SERVICE_PATH" ]; then
    echo "❌ Не удалось создать файл сервиса systemd!"
    exit 1
fi

# Перезагружаем systemd
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

# Проверяем статус сервиса
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "🎉 Сервис $SERVICE_NAME успешно запущен!"
else
    echo "⚠️ Сервис $SERVICE_NAME установлен, но не запущен"
    echo "🔧 Проверьте логи с помощью: journalctl -u $SERVICE_NAME -n 20"
fi
