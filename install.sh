#!/bin/bash

# Название для новой conda-среды
ENV_NAME="silero_rest_env"
CONDA_INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
CONDA_URL="https://repo.anaconda.com/miniconda/$CONDA_INSTALLER"
SERVICE_NAME="silero_rest_service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME.service"
PROJECT_DIR="$HOME/Silero-REST-Service"

# Проверяем, установлен ли conda
if ! command -v conda &> /dev/null; then
    echo "Conda не установлен. Устанавливаем Miniconda..."

    # Скачиваем Miniconda установщик
    wget $CONDA_URL -O $CONDA_INSTALLER

    # Устанавливаем Miniconda в автоматическом режиме (без запроса подтверждений у пользователя)
    bash $CONDA_INSTALLER -b

    # Добавляем conda в PATH
    export PATH="$HOME/miniconda3/bin:$PATH"

    # Инициализируем conda
    source "$HOME/miniconda3/bin/activate"

    # Удаляем установочный файл
    rm $CONDA_INSTALLER

    echo "Miniconda установлена."
else
    echo "Conda уже установлена."
fi

# Создаем новую conda-среду с Python 3.12
conda create -n $ENV_NAME python=3.12 -y

# Активируем созданную среду
source activate $ENV_NAME

# Устанавливаем зависимости через pip в активированной conda-среде
pip install fastapi uvicorn torch ruaccent

# Дополнительно, можно установить пакеты через conda, если они доступны
# Например, conda install pytorch torchvision torchaudio cpuonly -c pytorch

echo "Conda environment '$ENV_NAME' создана и все зависимости установлены."

# Создаем юнит для службы systemd
echo "Создаем юнит для службы systemd..."

sudo bash -c "cat > $SERVICE_PATH" <<EOL
[Unit]
Description=Silero REST Service
After=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$PROJECT_DIR
ExecStart=$HOME/miniconda3/envs/$ENV_NAME/bin/uvicorn silero_rest_service:app --host 0.0.0.0 --port 5010
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Перезагружаем systemd и запускаем сервис
echo "Перезагружаем systemd и запускаем сервис..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME
sudo systemctl start $SERVICE_NAME

echo "Служба $SERVICE_NAME создана и запущена."
