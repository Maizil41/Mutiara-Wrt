#!/bin/bash
set -e

apt update && apt install -y nodejs npm unzip wget curl expect

sleep 1

cd /root
wget -O api.zip https://raw.githubusercontent.com/Maizil41/Mutiara-Wrt/refs/heads/files/api.zip
unzip -o api.zip
rm api.zip

sleep 1

cd api

chmod +x *.exp

npm install

sleep 1

wget -O /etc/systemd/system/node-api.service https://raw.githubusercontent.com/Maizil41/Mutiara-Wrt/refs/heads/files/node-api.service

sleep 1

chmod 644 /etc/systemd/system/node-api.service
systemctl daemon-reload
systemctl enable node-api.service
systemctl start node-api.service

echo "=== Instalasi selesai dan service node-api sudah berjalan ==="
