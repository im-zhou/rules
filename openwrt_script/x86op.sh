#!/bin/bash
set -e

REPO_URL="https://github.com/coolsnowwolf/lede.git"
BRANCH="master"
DIR="lede"

if [ -d "$DIR/.git" ]; then
    echo ">>> 已存在 lede 仓库，开始更新..."
    cd "$DIR"
    origin_url=$(git config --get remote.origin.url)
    if [[ "$origin_url" != *"lede.git"* ]]; then
        echo ">>> 当前目录不是 lede 仓库，退出"
        exit 1
    fi
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

./scripts/feeds update -a
./scripts/feeds install -a

# 主机名
# sed -i 's/LEDE/H29K/g' package/base-files/files/bin/config_generate
# sed -i 's/LEDE/H29K/g' package/base-files/luci/bin/config_generate
# 更改默认IP
sed -i 's/192.168.1.1/192.168.105.3/g' package/base-files/files/bin/config_generate
# 默认 shell 为 bash
sed -i 's/\/bin\/ash/\/bin\/bash/g' package/base-files/files/etc/passwd
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
curl -fL https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz -o "$tmp_openclash/clash-linux-amd64.tar.gz"
tar -xzf "$tmp_openclash/clash-linux-amd64.tar.gz" -C "$tmp_openclash"
install -m 0755 "$tmp_openclash/clash" "$core_dir/clash_meta"
rm -rf -- "$tmp_openclash"
trap - EXIT

cp ../x86op.toml .config
make defconfig
env FORCE_UNSAFE_CONFIGURE=1 make download -j8
env FORCE_UNSAFE_CONFIGURE=1 make -j$(nproc)
