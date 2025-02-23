#!/bin/bash

# Определение архитектуры системы
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    CONDA_INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
elif [ "$ARCH" = "aarch64" ]; then
    CONDA_INSTALLER="Miniconda3-latest-Linux-aarch64.sh"
else
    echo "❌ Неподдерживаемая архитектура: $ARCH"
    exit 1
fi

# Остальные переменные
ENV_NAME="silero_rest_env"
CONDA_URL="https://repo.anaconda.com/miniconda/$CONDA_INSTALLER"
SERVICE_NAME="silero_rest_service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME.service"
PROJECT_DIR="$HOME/Silero-REST-Service"
CONDA_PATH="$HOME/miniconda3"

# Удаляем предыдущую установку Miniconda
echo "🗑️ Удаляем предыдущую установку Miniconda (если существует)..."
rm -rf $CONDA_PATH

# Проверяем, установлен ли conda
if ! command -v conda &> /dev/null; then
    echo "📦 Conda не установлен. Устанавливаем Miniconda для $ARCH..."

    # Скачиваем Miniconda установщик
    if ! wget $CONDA_URL -O $CONDA_INSTALLER; then
        echo "❌ Ошибка при скачивании Miniconda!"
        exit 1
    fi

    # Устанавливаем Miniconda
    if ! bash $CONDA_INSTALLER -b -p $CONDA_PATH; then
        echo "❌ Ошибка установки Miniconda!"
        exit 1
    fi

    # Инициализируем Conda
    source $CONDA_PATH/bin/activate
    conda init bash
    source ~/.bashrc

    # Удаляем установочный файл
    rm $CONDA_INSTALLER

    echo "✅ Miniconda успешно установлена"
else
    echo "ℹ️ Conda уже установлена"
fi

# Обновляем PATH
export PATH="$CONDA_PATH/bin:$PATH"

# Создаем новое окружение
echo "🛠️ Создаем окружение $ENV_NAME..."
conda create -n $ENV_NAME python=3.12 -y

# Активируем окружение
echo "🔌 Активируем окружение..."
conda activate $ENV_NAME

# Устанавливаем зависимости
echo "📦 Устанавливаем зависимости..."
pip install fastapi uvicorn torch ruaccent num2words

echo "✅ Окружение '$ENV_NAME' готово"

# Создаем systemd сервис
echo "⚙️ Настраиваем systemd сервис..."
sudo tee $SERVICE_PATH > /dev/null <<EOL
[Unit]
Description=Silero REST Service
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$PROJECT_DIR
ExecStart=$CONDA_PATH/envs/$ENV_NAME/bin/uvicorn silero_rest_service:app --host 0.0.0.0 --port 5010
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Перезагружаем systemd
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "🎉 Сервис $SERVICE_NAME успешно запущен!"
