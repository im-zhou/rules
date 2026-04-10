#!/usr/bin/env bash
set -e

VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep tag_name | cut -d '"' -f4)
echo "Using mihomo $VERSION"
wget -O - https://github.com/MetaCubeX/mihomo/releases/download/${VERSION}/mihomo-linux-amd64-v1-${VERSION}.gz | gunzip > mihomo
chmod +x mihomo

# https://github.com/MetaCubeX/meta-rules-dat/tree/meta

DOMAIN_URLS=(
  "oracle"
  "azure"
  "aws"
  "dmm"
)

ASNLIST=(
  "AS13335"   # Cloudflare
  "AS54113"   # Fastly
  "AS60068"   # Bunny
  "AS199524"  # Gcore
  "AS20940"   # Akamai
  "AS16625"   # Akamai
  "AS32787"   # Akamai
  # END CDN
  "AS3462"    # Hinet
  "AS4641"    # HKIX
  "AS9269"    # HKBN
  "AS4760"    # HKT
  "AS3491"    # PCCW
  "AS9908"    # iCable
  "AS31898"   # OCI
  "AS400618"  # RFCHost
  "AS17433"   # Hytron
  "AS202662"  # Hytron
  "AS151407"  # Hytron
  "AS401434"  # Hytron
  "AS205880"  # Hytron
  "AS12027"   # Hytron
  "AS16276"   # OVH
  "AS197540"  # Netcup
  "AS151487"  # Awesomecloud
  "AS48266"   # Catixs
  "AS53808"   # MoeDove
  "AS55933"   # Cloudie
  "AS976"     # CoreNET
  "AS132839"  # POWER LINE
  "AS62468"   # VpsQuan
)

echo ">>> download DOMAIN"
> domain_group.list
for site in "${DOMAIN_URLS[@]}"; do
  curl -L --retry 3 --connect-timeout 10 "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/$site.list" >> domain_group.list
  echo >> domain_group.list
done

echo ">>> download IPCIDR"
> ipcidr_group.list
for asn in "${ASNLIST[@]}"; do
  curl -L --retry 3 --connect-timeout 10 "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/asn/$asn.list" >> ipcidr_group.list
  echo >> ipcidr_group.list
done

echo ">>> dedupe"
sort -u domain_group.list -o domain_group.list
sort -u ipcidr_group.list -o ipcidr_group.list

echo ">>> convert"

./mihomo convert-ruleset domain text domain_group.list domain_group.mrs
./mihomo convert-ruleset ipcidr text ipcidr_group.list ipcidr_group.mrs

echo "done"