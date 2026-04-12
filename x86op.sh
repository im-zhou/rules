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
# 替换时区
sed -i "s/timezone='.*'/timezone='CST-8'/g" package/base-files/files/bin/config_generate
if ! grep -q "zonename=" package/base-files/files/bin/config_generate; then
    sed -i "/timezone='CST-8'/a \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ \ set system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate
else
    sed -i "s/zonename='.*'/zonename='Asia\/Shanghai'/g" package/base-files/files/bin/config_generate
fi

# OpenClash
rm -rf feeds/luci/applications/luci-app-openclash
git clone -b master --single-branch --filter=blob:none https://github.com/vernesong/OpenClash.git /tmp/OpenClash
rm -rf /tmp/OpenClash/luci-app-openclash/root/usr/share/openclash/ui/zashboard
mkdir -p /tmp/OpenClash/luci-app-openclash/root/usr/share/openclash/ui/zashboard
curl -L https://github.com/Zephyruso/zashboard/releases/latest/download/dist.zip -o /tmp/zashboard.zip
unzip -o /tmp/zashboard.zip -d /tmp/zashboard
mv /tmp/zashboard/dist/* /tmp/OpenClash/luci-app-openclash/root/usr/share/openclash/ui/zashboard/
rm -rf /tmp/zashboard /tmp/zashboard.zip
mv /tmp/OpenClash/luci-app-openclash feeds/luci/applications/luci-app-openclash
rm -rf /tmp/OpenClash
mkdir -p package/base-files/files/etc/openclash/core/
curl -L https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-amd64.tar.gz | tar -xz -C /tmp
mv /tmp/clash package/base-files/files/etc/openclash/core/clash_meta
chmod 0755 package/base-files/files/etc/openclash/core/clash_meta

echo "# Defaults are configured in /etc/sysctl.d/* and can be customized in this file" > package/base-files/files/etc/sysctl.conf
echo "net.core.rmem_max=524288" >> package/base-files/files/etc/sysctl.conf
sed -i '$a net.netfilter.nf_conntrack_max=65535' package/base-files/files/etc/sysctl.conf

cp ../x86op.toml .config
make defconfig
env FORCE_UNSAFE_CONFIGURE=1 make download -j8
env FORCE_UNSAFE_CONFIGURE=1 make -j$(nproc)
