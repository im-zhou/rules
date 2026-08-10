#!/bin/bash
set -e

CONFIG_FILE=".config"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "错误：找不到配置文件 $CONFIG_FILE" >&2
    exit 1
fi
TARCH=$(sed -n 's/^CONFIG_ARCH="\([^"]*\)"/\1/p' "$CONFIG_FILE" | head -n 1)
case "$TARCH" in
    x86_64)
        TARCH="amd64"
        ;;
    aarch64)
        TARCH="arm64"
        ;;
    arm)
        TARCH="arm"
        ;;
    i386|i486|i586|i686)
        TARCH="386"
        ;;
    "")
        echo "错误：无法从 $CONFIG_FILE 获取 CONFIG_ARCH" >&2
        exit 1
        ;;
    *)
        echo "错误：不支持的架构：$TARCH" >&2
        exit 1
        ;;
esac
echo "当前架构：$TARCH"

# OpenClash
tmp_openclash="$(mktemp -d)"
trap 'rm -rf -- "$tmp_openclash"' EXIT
git clone -b master --single-branch --filter=blob:none https://github.com/vernesong/OpenClash.git "$tmp_openclash/OpenClash"
zashboard_dir="$tmp_openclash/OpenClash/luci-app-openclash/root/usr/share/openclash/ui/zashboard"
rm -rf -- "$zashboard_dir"
mkdir -p "$zashboard_dir"
curl -fL https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip -o "$tmp_openclash/zashboard.zip"
unzip -oq "$tmp_openclash/zashboard.zip" -d "$tmp_openclash/zashboard"
cp -a "$tmp_openclash/zashboard/dist/." "$zashboard_dir/"
rm -rf -- feeds/luci/applications/luci-app-openclash
mkdir -p feeds/luci/applications
mv "$tmp_openclash/OpenClash/luci-app-openclash" feeds/luci/applications/luci-app-openclash
core_dir="package/base-files/files/etc/openclash/core"
mkdir -p "$core_dir"
curl -fL https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-$TARCH.tar.gz -o "$tmp_openclash/clash-linux-$TARCH.tar.gz"
tar -xzf "$tmp_openclash/clash-linux-$TARCH.tar.gz" -C "$tmp_openclash"
install -m 0755 "$tmp_openclash/clash" "$core_dir/clash_meta"
rm -rf -- "$tmp_openclash"
trap - EXIT
