#!/bin/sh

wget -O /tmp/Bahan.zip https://github.com/Maizil41/Mutiara-Wrt/raw/beta/Bahan.zip

unzip /tmp/Bahan.zip -d /tmp/

mv /tmp/Bahan/whatsapp /usr/lib/lua/luci/view/

rm -f /www/luci-static/resources/view/whatsapp/setting.js

mv /tmp/Bahan/setting.js /www/luci-static/resources/view/whatsapp/

rm -f /usr/share/luci/menu.d/luci-app-whatsapp-bot.json

mv /tmp/Bahan/luci-app-whatsapp-bot.json /usr/share/luci/menu.d/

rm -f /tmp/Bahan.zip
rm -rf /tmp/Bahan
