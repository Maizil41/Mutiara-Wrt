#!/bin/sh

# (echo "mutiara"; sleep 1; echo "mutiara") | passwd > /dev/null

echo "Setup NTP Server and Time Zone to Asia/Jakarta"
uci set system.@system[0].hostname='mutiara-wrt'
uci set system.@system[0].timezone='WIB-7'
uci set system.@system[0].zonename='Asia/Jakarta'
uci commit system

sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf
echo "src/gz mutiara_wrt https://raw.githubusercontent.com/maizil41/mutiara-wrt-opkg/main/generic" >> /etc/opkg/customfeeds.conf

echo "First setup complete!"
rm -- "$0"
