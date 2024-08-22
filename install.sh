#!/bin/bash

# Обновление и установка необходимых пакетов
sudo apt-get update
sudo apt-get install -y python3 python3-venv python3-pip

# Создание и активация виртуального окружения
python3 -m venv venv
source venv/bin/activate

# Установка зависимостей
pip install --upgrade pip
pip install -r requirements.txt

# Создание systemd сервиса
SERVICE_FILE=/etc/systemd/system/silero_rest_service.service

sudo bash -c "cat > $SERVICE_FILE" << EOF
[Unit]
Description=Silero REST Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/venv/bin/uvicorn silero_rest_service:app --host 0.0.0.0 --port 5010
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd, включение и запуск сервиса
sudo systemctl daemon-reload
sudo systemctl enable silero_rest_service.service
sudo systemctl start silero_rest_service.service

echo "Установка завершена. Сервис запущен и будет автоматически стартовать при загрузке системы."
