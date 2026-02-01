include $(TOPDIR)/rules.mk

PKG_NAME    := prometheus-node-exporter-lua-podman
PKG_VERSION := 1.0.0
PKG_RELEASE := 1

PKG_MAINTAINER    := CSoellinger
PKG_URL           := https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman
PKG_LICENSE       := Apache-2.0
PKG_LICENSE_FILES := LICENSE

include $(INCLUDE_DIR)/package.mk

Build/Compile=

#
# Podman Basic exporter
#
define Package/$(PKG_NAME)
  SECTION  := utils
  CATEGORY := Utilities
  TITLE    := Prometheus node exporter (podman collector)
  URL      := $(PKG_URL)
  PKGARCH  := all
  DEPENDS  := +prometheus-node-exporter-lua +lua-cjson +lua-curl-v3 +libnixio-lua +podman
endef

define Package/$(PKG_NAME)/description
  Basic Podman metrics collector for prometheus-node-exporter-lua.
  Collects container, pod, image, network, volume, and system info metrics.
  Low overhead - single API call per resource type.
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/prometheus-collectors
	$(INSTALL_DATA) ./files/podman.lua $(1)/usr/lib/lua/prometheus-collectors/
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/prometheus-node-exporter-lua restart 2>/dev/null
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/prometheus-node-exporter-lua restart 2>/dev/null
exit 0
endef

#
# Podman Advanced exporter
#
define Package/$(PKG_NAME)-container
  SECTION  := utils
  CATEGORY := Utilities
  TITLE    := Prometheus node exporter (podman per-container stats)
  URL      := $(PKG_URL)
  PKGARCH  := all
  DEPENDS  := +prometheus-node-exporter-lua +lua-cjson +lua-curl-v3 +libnixio-lua +podman
endef

define Package/$(PKG_NAME)-container/description
  Per-container stats collector for prometheus-node-exporter-lua.
  Collects CPU, memory, block I/O, network, and PID stats per container.
  Medium overhead - one API call per running container.
endef

define Package/$(PKG_NAME)-container/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/prometheus-collectors
	$(INSTALL_DATA) ./files/podman-container.lua $(1)/usr/lib/lua/prometheus-collectors/
endef

define Package/$(PKG_NAME)-container/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/prometheus-node-exporter-lua restart 2>/dev/null
exit 0
endef

define Package/$(PKG_NAME)-container/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/prometheus-node-exporter-lua restart 2>/dev/null
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
$(eval $(call BuildPackage,$(PKG_NAME)-container))
