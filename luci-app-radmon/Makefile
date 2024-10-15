# This is free software, licensed under the Apache License, Version 2.0
#
# Copyright (C) 2024 Maizil <maizilpc7@gmail.com>

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI for Radius Monitor.
LUCI_DEPENDS:=+luci +php7-cli +php7-mod-mysqli +php7-mod-pdo-mysql +php7-mod-gd +php7-mod-xml +php7-mod-filter +php7-mod-curl
LUCI_DESCRIPTION:=Application for monitoring RADIUS server.
LUCI_MAINTAINER:=Maizil <maizilpc7@gmail.com>

PKG_MAINTAINER:=Maizil <maizilpc7@gmail.com>
PKG_VERSION:=2.3
PKG_RELEASE:=beta
PKG_LICENSE:=Apache-2.0
PKG_ARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
