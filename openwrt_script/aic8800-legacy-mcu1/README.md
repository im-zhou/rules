# OpenWrt AIC8800D80 legacy MCU1 USB 驱动适配

本目录用于在 `coolsnowwolf/lede` 的 `package/kernel/aic8800` 中，将 USB 驱动和 USB 固件替换为支持 legacy MCU1 的版本，同时保留原有 PCIe、SDIO 驱动来源。

## 问题原因

部分 AIC8800D80 USB 设备使用旧版 MCU，驱动启动时可看到类似信息：

```text
Aic high speed USB device detected
chip_id=7, chip_mcu_id = 1
aic_load_firmware :firmware path = /lib/firmware/aic8800/usb/fw_patch_table_8800d80_u02.bin
### Upload fw_patch_table_8800d80_u02.bin fw_patch_table, size=1384
addr_adid 0x201940, addr_patch 0x1e0000
aic_load_firmware :firmware path = /lib/firmware/aic8800/usb/fw_adid_8800d80_u02.bin
### Upload fw_adid_8800d80_u02.bin firmware, @ = 201940 size=1708
aic_load_firmware :firmware path = /lib/firmware/aic8800/usb/fw_patch_8800d80_u02.bin
### Upload fw_patch_8800d80_u02.bin firmware, @ = 1e0000 size=32700
aic_load_firmware :firmware path = /lib/firmware/aic8800/usb/fw_patch_8800d80_u02_ext0.bin
### Upload fw_patch_8800d80_u02_ext0.bin firmware, @ = 20b43c size=16136
patch version - Aug 01 2025 11:05:26 - git a26f071
aic_load_firmware :firmware path = /lib/firmware/aic8800/usb/fmacfw_8800d80_u02.bin
### Upload fmacfw_8800d80_u02.bin firmware, @ = 120000 size=358072
cmd timed-out
tkn[511] flags:0012 result: -4 cmd:1035 - reqcfm(1036)
cmd queue crashed
bin upload fail: 170400, err:-32
aicwf_bus_deinit
usb_err:<aicwf_usb_rx_submit_all_urb,234>: bus is not up=0
q_sz/max: 0 / 8 - next tkn: 512
```

LEDE 原包使用的 Radxa 源码主要用于现有 PCIe、SDIO 和较新的 USB 方案；legacy MCU1 设备需要 `shenmintao/aic8800d80` 的 [`legacy-mcu1`](https://github.com/shenmintao/aic8800d80/tree/legacy-mcu1) 分支及配套固件，否则可能出现固件不匹配、设备复位后驱动不能正常启动等问题。

## 文件说明

- `Makefile`
  - PCIe、SDIO 继续使用 `radxa-pkg/aic8800`。
  - USB 使用 `shenmintao/aic8800d80` 的 legacy MCU1 固定提交：
    `4b717f40489f94988713474eb3bd7d75ba83b292`。
  - USB 固件统一安装到 `/lib/firmware/aic8800/usb/`，不再按芯片建立子目录。
  - USB 模块编译为 `aic8800_usb_fdrv.ko`，并隔离与 SDIO 驱动重复的导出符号。

- `100-legacy-mcu1-openwrt-compat.patch`
  - 增加 OpenWrt/Linux 内核兼容修改。
  - 修正 USB 与 SDIO 同时编译时的符号冲突。
  - 将 USB 驱动默认固件路径改为 `/lib/firmware/aic8800/usb`。
  - 删除驱动读取固件时自动追加芯片子目录的逻辑。
  - 关闭大量不影响运行的启动信息日志。

## 已关闭的日志

这些输出只是正常启动过程中的状态或配置表 dump，关闭后不会跳过配置解析、功率设置或固件命令发送：

- `get_txpwr_max:txpwr_max:18`
- `usb_busrx_thread`、`usb_bustx_thread` 的 CPU、绑核结果、调度策略、实时优先级和 PID 输出
- `rwnx_plat_nvram_set_value` 对每个 userconfig 项目的打印
- `get_userconfig_txpwr_lvl_v3_in_fdrv` 的完整功率等级表
- `rwnx_send_txpwr_lvl_v3_req` 发送前的完整功率等级表
- `get_userconfig_txpwr_lvl_adj_in_fdrv` 和 `rwnx_send_txpwr_lvl_adj_req` 的功率调整表
- `get_userconfig_txpwr_ofst2x_in_fdrv` 和 `rwnx_send_txpwr_ofst2x_req` 的功率偏移矩阵
- `get_userconfig_xtal_cap` 的晶振电容参数输出
- `rwnx_send_rf_calib_req` 的普通入口信息

固件打开失败、USB 异常、内存分配失败、命令超时以及其他 `LOGERROR` 仍然保留。USB 线程绑核成功时不再打印，绑核失败时仍会输出一条错误信息。

## 替换方法

假设 LEDE 源码目录为 `lede`，将本目录中的两个文件复制到原包目录：

```bash
cp aic8800-legacy-mcu1/Makefile \
  lede/package/kernel/aic8800/Makefile

cp aic8800-legacy-mcu1/100-legacy-mcu1-openwrt-compat.patch \
  lede/package/kernel/aic8800/100-legacy-mcu1-openwrt-compat.patch
```

补丁由 `Makefile` 的 `Build/Prepare` 自动应用，不要再手动执行 `git apply` 或 `patch`，否则会重复应用。

进入 LEDE 目录后确认选择 USB 驱动：

```bash
cd lede
make menuconfig
```

对应软件包为：

```text
kmod-aic8800-usb
aic8800-usb-firmware
```

选择 `kmod-aic8800-usb` 后，固件包会作为依赖自动选中。

## 清理和重新编译

替换 Makefile 或补丁后必须先清理旧的构建目录，使 `Build/Prepare` 重新解压源码并应用新补丁：

```bash
make package/kernel/aic8800/clean
make package/kernel/aic8800/compile V=s -j1
```

确认单线程编译正常后，可以恢复并行编译：

```bash
make package/kernel/aic8800/compile V=s -j"$(nproc)"
```

如果直接编译完整固件，同样建议先执行包级清理，再运行原来的固件编译命令。

## 验证

安装后可检查模块、网卡和固件路径：

```bash
lsmod | grep aic8800
iw dev
dmesg | grep -Ei 'aic|firmware|usb'
```

正常情况下，USB 固件应从以下目录读取：

```text
/lib/firmware/aic8800/usb/
```

不应再出现从 `/lib/firmware/aic8800D80/` 读取固件的日志，也不应再连续输出功率配置表。
