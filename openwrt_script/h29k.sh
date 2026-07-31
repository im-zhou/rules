#!/bin/bash
set -e

REPO_URL="https://github.com/coolsnowwolf/lede.git"
BRANCH="master"
DIR="lede"

if [ -d "$DIR/.git" ]; then
    echo ">>> 已存在 lede 仓库，开始更新..."
    cd "$DIR"
    # 确保是正确的仓库（防止误操作）
    origin_url=$(git config --get remote.origin.url)
    if [[ "$origin_url" != *"lede"* ]]; then
        echo ">>> 当前目录不是 lede 仓库，退出"
        exit 1
    fi
    # 拉取并强制同步
    git fetch origin
    git reset --hard origin/$BRANCH
    git clean -fd
    echo ">>> 更新完成"
else
    echo ">>> 未检测到 lede 仓库，开始克隆..."
    git clone -b $BRANCH --single-branch $REPO_URL $DIR
    echo ">>> 克隆完成"
    cd "$DIR"
fi

feed_line='src-git qmodem https://github.com/FUjr/QModem'
feed_file='feeds.conf.default'
if grep -Eq '^[[:space:]]*src-git[[:space:]]+qmodem([[:space:]]|$)' "$feed_file"; then
    # qmodem 已存在且未注释：无论仓库或分支是否不同，都替换为指定内容
    sed -i -E "s|^[[:space:]]*src-git[[:space:]]+qmodem([[:space:]].*)?$|${feed_line}|" "$feed_file"
else
    # 不存在未注释的 qmodem 配置：追加新行
    printf '%s\n' "$feed_line" >> "$feed_file"
fi

./scripts/feeds update -a
./scripts/feeds install -a

# 主机名
sed -i 's/LEDE/H29K/g' package/base-files/files/bin/config_generate
sed -i 's/LEDE/H29K/g' package/base-files/luci/bin/config_generate
# 更改默认IP
sed -i 's/192.168.1.1/192.168.105.1/g' package/base-files/files/bin/config_generate
# 默认 shell 为 bash
sed -i 's/\/bin\/ash/\/bin\/bash/g' package/base-files/files/etc/passwd
# 修改 WiFi 名称（SSID）从 LEDE → H29K
sed -i 's/set wireless.default_radio${devidx}.ssid=LEDE/set wireless.default_radio${devidx}.ssid=H29K/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# 修改加密方式 (none → psk2)
sed -i 's/set wireless.default_radio${devidx}.encryption=none/set wireless.default_radio${devidx}.encryption=psk2/' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# 在加密行后新增密码行 (确保格式对齐)
sed -i '/set wireless.default_radio${devidx}.encryption=psk2/a \\t\tset wireless.default_radio${devidx}.key=12345678' package/kernel/mac80211/files/lib/wifi/mac80211.sh
# 替换ntp服务器
sed -i 's/0.openwrt.pool.ntp.org/ntp.tencent.com/g' package/base-files/files/bin/config_generate
sed -i 's/1.openwrt.pool.ntp.org/ntp1.aliyun.com/g' package/base-files/files/bin/config_generate
sed -i 's/2.openwrt.pool.ntp.org/ntp.ntsc.ac.cn/g' package/base-files/files/bin/config_generate
sed -i 's/3.openwrt.pool.ntp.org/cn.ntp.org.cn/g' package/base-files/files/bin/config_generate
# 替换时区
sed -i "s/timezone='.*'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
if ! grep -q "zonename=" package/base-files/files/bin/config_generate; then
    sed -i "/timezone='CST-8'/a \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate
else
    sed -i "s/zonename='.*'/zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate
fi
#由于内核参数 net.core.rmem_max 的限制，缓冲区大小被限制为 212992 字节，永久设置 Netlink 接收缓冲区大小为 524288 字节。
echo "# Defaults are configured in /etc/sysctl.d/* and can be customized in this file" > package/base-files/files/etc/sysctl.conf
echo "net.core.rmem_max=524288" >> package/base-files/files/etc/sysctl.conf
sed -i '$a net.netfilter.nf_conntrack_max=65535' package/base-files/files/etc/sysctl.conf

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
curl -fL https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-arm64.tar.gz -o "$tmp_openclash/clash-linux-arm64.tar.gz"
tar -xzf "$tmp_openclash/clash-linux-arm64.tar.gz" -C "$tmp_openclash"
install -m 0755 "$tmp_openclash/clash" "$core_dir/clash_meta"
rm -rf -- "$tmp_openclash"
trap - EXIT

# main
cp ../h29k.toml .config
make defconfig
env FORCE_UNSAFE_CONFIGURE=1 make download -j8
env FORCE_UNSAFE_CONFIGURE=1 make -j$(nproc)
