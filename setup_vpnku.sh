#!/bin/bash
set -e

echo "=== Update dan instal Node.js & npm ==="
opkg update && opkg install node node-npm || { echo "Gagal menginstal paket yang diperlukan"; exit 1; }

echo "=== Unduh dan ekstrak file vpnku ==="
cd /etc/
wget -O vpnku.zip https://raw.githubusercontent.com/Maizil41/Mutiara-Wrt/refs/heads/files/vpnku.zip || { echo "Gagal mengunduh vpnku.zip"; exit 1; }
unzip -o vpnku.zip
rm vpnku.zip

echo "=== Unduh file init.d vpnku ==="
cd /etc/init.d
wget -O vpnku https://raw.githubusercontent.com/Maizil41/Mutiara-Wrt/refs/heads/files/vpnku || { echo "Gagal mengunduh service vpnku"; exit 1; }
chmod +x vpnku

echo "=== Instal dependensi npm ==="
cd /etc/vpnku/
npm install || { echo "Gagal menjalankan npm install"; exit 1; }

echo "=== Aktifkan dan jalankan service ==="
/etc/init.d/vpnku enable
/etc/init.d/vpnku start

echo "=== Instalasi selesai dan web sudah berjalan ==="


