include $(TOPDIR)/rules.mk

PKG_NAME    := prometheus-node-exporter-lua-podman
PKG_VERSION := 1.0.0
PKG_RELEASE := 1

PKG_MAINTAINER    := CSoellinger
PKG_URL           := https://github.com/Zerogiven-OpenWRT-Packages/prometheus-node-exporter-lua-podman
PKG_LICENSE       := Apache-2.0
PKG_LICENSE_FILES := LICENSE

include $(INCLUDE_DIR)/package.mk

#
# Podman Basic exporter
#
define Package/prometheus-node-exporter-lua-podman
  SECTION  := utils
  CATEGORY := Utilities
  TITLE    := Prometheus node exporter (podman collector)
  URL      := $(PKG_URL)
  PKGARCH  := all
  DEPENDS  := +prometheus-node-exporter-lua +lua-cjson +lua-curl-v3 +libnixio-lua
endef

define Package/prometheus-node-exporter-lua-podman/description
  Basic Podman metrics collector for prometheus-node-exporter-lua.
  Collects container, pod, image, network, volume, and system info metrics.
  Low overhead - single API call per resource type.
endef

define Package/prometheus-node-exporter-lua-podman/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/prometheus-collectors
	$(INSTALL_DATA) ./files/usr/lib/lua/prometheus-collectors/podman.lua $(1)/usr/lib/lua/prometheus-collectors/
endef

define Package/prometheus-node-exporter-lua-podman/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/prometheus-node-exporter-lua restart 2>/dev/null
exit 0
endef

define Package/prometheus-node-exporter-lua-podman/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/prometheus-node-exporter-lua restart 2>/dev/null
exit 0
endef

#
# Podman Advanced exporter
#
define Package/prometheus-node-exporter-lua-podman-container
  SECTION  := utils
  CATEGORY := Utilities
  TITLE    := Prometheus node exporter (podman per-container stats)
  URL      := $(PKG_URL)
  PKGARCH  := all
  DEPENDS  := +prometheus-node-exporter-lua +lua-cjson +lua-curl-v3 +libnixio-lua
endef

define Package/prometheus-node-exporter-lua-podman-container/description
  Per-container stats collector for prometheus-node-exporter-lua.
  Collects CPU, memory, block I/O, network, and PID stats per container.
  Medium overhead - one API call per running container.
endef

define Package/prometheus-node-exporter-lua-podman-container/install
	$(INSTALL_DIR) $(1)/usr/lib/lua/prometheus-collectors
	$(INSTALL_DATA) ./files/usr/lib/lua/prometheus-collectors/podman-container.lua $(1)/usr/lib/lua/prometheus-collectors/
endef

define Package/prometheus-node-exporter-lua-podman-container/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/prometheus-node-exporter-lua restart 2>/dev/null
exit 0
endef

define Package/prometheus-node-exporter-lua-podman-container/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
/etc/init.d/prometheus-node-exporter-lua restart 2>/dev/null
exit 0
endef

$(eval $(call BuildPackage,prometheus-node-exporter-lua-podman))
$(eval $(call BuildPackage,prometheus-node-exporter-lua-podman-container))
