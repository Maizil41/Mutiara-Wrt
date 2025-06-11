#!/bin/sh

wget -O /tmp/Bahan.zip https://github.com/Maizil41/Mutiara-Wrt/raw/beta/Bahan.zip

sleep 1

unzip /tmp/Bahan.zip -d /tmp/

sleep 1

rm -rf /usr/lib/lua/luci/view/whatsapp

sleep 1

mv /tmp/Bahan/whatsapp /usr/lib/lua/luci/view/

sleep 1

rm -f /www/luci-static/resources/view/whatsapp/setting.js

sleep 1

mv /tmp/Bahan/setting.js /www/luci-static/resources/view/whatsapp/

sleep 1

rm -f /usr/share/luci/menu.d/luci-app-whatsapp-bot.json

sleep 1

mv /tmp/Bahan/luci-app-whatsapp-bot.json /usr/share/luci/menu.d/

sleep 1

rm -f /tmp/Bahan.zip
rm -rf /tmp/Bahan
