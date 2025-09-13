#!/bin/bash

set -e

apt update && apt install -y npm

sleep 1

cd /
wget -O api.zip https://raw.githubusercontent.com/Maizil41/Mutiara-Wrt/refs/heads/files/api.zip
unzip -o api.zip
rm api.zip

sleep 1

cd api
npm install

sleep 1

wget -O /etc/systemd/system/node-api.service https://raw.githubusercontent.com/Maizil41/Mutiara-Wrt/refs/heads/files/node-api.service

sleep 1

chmod +x /etc/systemd/system/node-api.service
systemctl daemon-reload
systemctl enable node-api.service
systemctl start node-api.service

echo "=== Instalasi selesai dan service node-api sudah berjalan ==="

