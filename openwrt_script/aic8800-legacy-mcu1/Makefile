# SPDX-License-Identifier: GPL-2.0+
#
# Copyright (c) 2023-2025 AnYun
#

include $(TOPDIR)/rules.mk

PKG_NAME:=aic8800
PKG_RELEASE:=5

# Radxa source remains the source for PCIe and SDIO.
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/radxa-pkg/aic8800.git
PKG_SOURCE_DATE:=2026-03-30
PKG_SOURCE_VERSION:=89f865b80f5f2ba6c0711c560e1d0191e87a1bf0
PKG_MIRROR_HASH:=1cdebf3a7900b8919f77e92353ac029358c462f432f6883108220672633a6784

# USB driver and matching firmware for chip_mcu_id=1 legacy hardware.
AIC8800_USB_SOURCE_DATE:=2026-08-17
AIC8800_USB_SOURCE_VERSION:=4b717f40489f94988713474eb3bd7d75ba83b292
AIC8800_USB_SOURCE_SUBDIR:=aic8800d80-$(AIC8800_USB_SOURCE_DATE)-4b717f40
AIC8800_USB_SOURCE:=$(AIC8800_USB_SOURCE_SUBDIR).tar.xz
AIC8800_USB_SOURCE_URL:=https://github.com/shenmintao/aic8800d80.git
AIC8800_USB_MIRROR_HASH:=e5e9ba665bed6f4f81a102b7f9bab0dc80283610c261a38304bb708766c64b33

PKG_FLAGS:=nonshared

include $(INCLUDE_DIR)/kernel.mk
include $(INCLUDE_DIR)/package.mk

AIC8800_USB_BUILD_DIR:=$(PKG_BUILD_DIR)/$(AIC8800_USB_SOURCE_SUBDIR)

define Download/aic8800-usb-legacy-mcu1
  FILE:=$(AIC8800_USB_SOURCE)
  URL:=$(AIC8800_USB_SOURCE_URL)
  PROTO:=git
  VERSION:=$(AIC8800_USB_SOURCE_VERSION)
  SUBDIR:=$(AIC8800_USB_SOURCE_SUBDIR)
  MIRROR_HASH:=$(AIC8800_USB_MIRROR_HASH)
endef
$(eval $(call Download,aic8800-usb-legacy-mcu1))

define Build/Prepare
	$(call Build/Prepare/Default)
	$(TAR) -C $(PKG_BUILD_DIR) -xf $(DL_DIR)/$(AIC8800_USB_SOURCE)
	$(PATCH) -d $(AIC8800_USB_BUILD_DIR) -p1 < \
		$(CURDIR)/100-legacy-mcu1-openwrt-compat.patch
	$(SED) 's/MODULE_NAME = aic8800_fdrv/MODULE_NAME = aic8800_usb_fdrv/' \
		$(AIC8800_USB_BUILD_DIR)/drivers/aic8800/aic8800_fdrv/Makefile
endef

define Package/aic8800-firmware/Default
  SECTION:=firmware
  CATEGORY:=Firmware
  TITLE:=Aicsemi aic8800 $(1) firmware
endef

Package/aic8800-pcie-firmware = $(call Package/aic8800-firmware/Default,PCIe)
Package/aic8800-sdio-firmware = $(call Package/aic8800-firmware/Default,SDIO)
Package/aic8800-usb-firmware = $(call Package/aic8800-firmware/Default,USB legacy MCU1)

define KernelPackage/aic8800/Default
  SUBMENU:=Wireless Drivers
  TITLE:=Aicsemi aic8800 Wi-Fi $(1) support
  DEPENDS:=+kmod-cfg80211 +@DRIVER_11N_SUPPORT +@DRIVER_11AC_SUPPORT +@DRIVER_11AX_SUPPORT
endef

define KernelPackage/aic8800-pcie
  $(call KernelPackage/aic8800/Default,PCIe)
  DEPENDS+= +aic8800-pcie-firmware @PCIE_SUPPORT
  FILES:=$(PKG_BUILD_DIR)/src/PCIE/driver_fw/driver/aic8800/aic8800_fdrv/aic8800D80_fdrv.ko
  AUTOLOAD:=$(call AutoProbe,aic8800D80_fdrv)
endef

define KernelPackage/aic8800-sdio
  $(call KernelPackage/aic8800/Default,SDIO)
  DEPENDS+= +aic8800-sdio-firmware +kmod-mmc +kmod-bluetooth
  FILES:= \
	$(PKG_BUILD_DIR)/src/SDIO/driver_fw/driver/aic8800/aic8800_bsp/aic8800_bsp.ko \
	$(PKG_BUILD_DIR)/src/SDIO/driver_fw/driver/aic8800/aic8800_fdrv/aic8800_fdrv.ko
  AUTOLOAD:=$(call AutoProbe,aic8800_bsp aic8800_fdrv)
endef

define KernelPackage/aic8800-usb
  $(call KernelPackage/aic8800/Default,USB legacy MCU1)
  DEPENDS+= +aic8800-usb-firmware +kmod-usb-core +kmod-btusb @USB_SUPPORT
  FILES:= \
	$(AIC8800_USB_BUILD_DIR)/drivers/aic8800/aic_load_fw/aic_load_fw.ko \
	$(AIC8800_USB_BUILD_DIR)/drivers/aic8800/aic8800_fdrv/aic8800_usb_fdrv.ko
  AUTOLOAD:=$(call AutoProbe,aic_load_fw aic8800_usb_fdrv)
endef

NOSTDINC_FLAGS:= \
	$(KERNEL_NOSTDINC_FLAGS) \
	-I$(PKG_BUILD_DIR) \
	-I$(PKG_BUILD_DIR)/include \
	-I$(STAGING_DIR)/usr/include/mac80211-backport \
	-I$(STAGING_DIR)/usr/include/mac80211-backport/uapi \
	-I$(STAGING_DIR)/usr/include/mac80211 \
	-I$(STAGING_DIR)/usr/include/mac80211/uapi \
	-include backport/autoconf.h \
	-include backport/backport.h \
	-DBUILD_OPENWRT

# These four names are also exported by the Radxa SDIO BSP. Rename only the
# legacy USB copies so USB and SDIO can be selected in the same firmware.
AIC8800_USB_NOSTDINC_FLAGS:= \
	$(NOSTDINC_FLAGS) \
	-Daicwf_prealloc_txq_alloc=aicusb_prealloc_txq_alloc \
	-Dget_adap_test=aicusb_get_adap_test \
	-Dget_fw_path=aicusb_get_fw_path \
	-Dget_testmode=aicusb_get_testmode

define Build/Compile

ifneq ($(CONFIG_PACKAGE_kmod-aic8800-sdio),)
	+$(KERNEL_MAKE) $(PKG_JOBS) \
		M="$(PKG_BUILD_DIR)/src/SDIO/driver_fw/driver/aic8800" \
		NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
		CONFIG_AIC_FW_PATH="/lib/firmware/aic8800/sdio" \
		CONFIG_AIC8800_BTLPM_SUPPORT=n \
		CONFIG_SDIO_BT=y \
		modules
endif
ifneq ($(CONFIG_PACKAGE_kmod-aic8800-pcie),)
	+$(KERNEL_MAKE) $(PKG_JOBS) \
		M="$(PKG_BUILD_DIR)/src/PCIE/driver_fw/driver/aic8800/aic8800_fdrv" \
		NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
		CONFIG_AIC_FW_PATH="/lib/firmware/aic8800/pcie" \
		modules
endif
ifneq ($(CONFIG_PACKAGE_kmod-aic8800-usb),)
	+$(KERNEL_MAKE) $(PKG_JOBS) \
		M="$(AIC8800_USB_BUILD_DIR)/drivers/aic8800" \
		NOSTDINC_FLAGS="$(AIC8800_USB_NOSTDINC_FLAGS)" \
		CONFIG_AIC_LOADFW_SUPPORT=m \
		CONFIG_AIC8800_WLAN_SUPPORT=m \
		CONFIG_AIC_ZLP_QUIRK=n \
		CONFIG_PLATFORM_UBUNTU=y \
		CONFIG_PLATFORM_ROCKCHIP=n \
		CONFIG_PLATFORM_ALLWINNER=n \
		CONFIG_PLATFORM_AMLOGIC=n \
		CONFIG_PLATFORM_HI=n \
		CONFIG_AIC_FW_PATH="/lib/firmware/aic8800/usb" \
		modules
endif
endef

define Package/aic8800-pcie-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware/aic8800/pcie
	$(CP) \
		$(PKG_BUILD_DIR)/src/PCIE/driver_fw/fw/aic8800D80/* \
		$(1)/lib/firmware/aic8800/pcie/
endef

define Package/aic8800-sdio-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware/aic8800/sdio
	$(CP) \
		$(PKG_BUILD_DIR)/src/SDIO/driver_fw/fw/aic8800/* \
		$(1)/lib/firmware/aic8800/sdio/
	$(CP) \
		$(PKG_BUILD_DIR)/src/SDIO/driver_fw/fw/aic8800D80/* \
		$(1)/lib/firmware/aic8800/sdio/
	$(CP) \
		$(PKG_BUILD_DIR)/src/SDIO/driver_fw/fw/aic8800D80N/* \
		$(1)/lib/firmware/aic8800/sdio/
	$(CP) \
		$(PKG_BUILD_DIR)/src/SDIO/driver_fw/fw/aic8800D80X2/* \
		$(1)/lib/firmware/aic8800/sdio/
	$(CP) \
		$(PKG_BUILD_DIR)/src/SDIO/driver_fw/fw/aic8800DC/* \
		$(1)/lib/firmware/aic8800/sdio/
endef

define Package/aic8800-usb-firmware/install
	$(INSTALL_DIR) $(1)/lib/firmware/aic8800/usb
	$(INSTALL_DATA) $(AIC8800_USB_BUILD_DIR)/fw/aic8800/* \
		$(1)/lib/firmware/aic8800/usb/
	$(INSTALL_DATA) $(AIC8800_USB_BUILD_DIR)/fw/aic8800D80/* \
		$(1)/lib/firmware/aic8800/usb/
	$(INSTALL_DATA) $(AIC8800_USB_BUILD_DIR)/fw/aic8800D80N/* \
		$(1)/lib/firmware/aic8800/usb/
	$(INSTALL_DATA) $(AIC8800_USB_BUILD_DIR)/fw/aic8800D80X2/* \
		$(1)/lib/firmware/aic8800/usb/
	$(INSTALL_DATA) $(AIC8800_USB_BUILD_DIR)/fw/aic8800DC/* \
		$(1)/lib/firmware/aic8800/usb/
	$(INSTALL_DATA) $(AIC8800_USB_BUILD_DIR)/fw/aic8800DLN/* \
		$(1)/lib/firmware/aic8800/usb/
endef

$(eval $(call BuildPackage,aic8800-pcie-firmware))
$(eval $(call BuildPackage,aic8800-sdio-firmware))
$(eval $(call BuildPackage,aic8800-usb-firmware))
$(eval $(call KernelPackage,aic8800-pcie))
$(eval $(call KernelPackage,aic8800-sdio))
$(eval $(call KernelPackage,aic8800-usb))
