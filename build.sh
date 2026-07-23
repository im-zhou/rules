#!/usr/bin/env bash
# upstream:
# https://github.com/MetaCubeX/meta-rules-dat/tree/meta
#
. ./conf.sh
. ./eu.sh
. ./funcs.sh
set -euo pipefail

echo "Step: Download mihomo"
download_mihomo 5 3

echo "Step: Build GeoASN"
mkdir -p dist/meta/asn
wget -qO ./convert/GeoLite2-ASN.mmdb https://raw.githubusercontent.com/Loyalsoldier/geoip/release/GeoLite2-ASN.mmdb
go run -C convert/ ./ asn  -f ./GeoLite2-ASN.mmdb -o ../dist/meta/asn

echo "Step: Build GeoIP"
mkdir -p dist/meta/geoip
wget -qO ./convert/geoip.dat https://github.com/Loyalsoldier/geoip/raw/release/geoip.dat
go run -C convert/ ./ geoip -f ./geoip.dat -o ../dist/meta/geoip

echo "Step: Merge DomainList"
true > domain_group.list
for site in "${DOMAIN_URLS[@]}"; do
  curl -sL --retry 3 --connect-timeout 10 "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/$site.list" >> domain_group.list
  echo >> domain_group.list
done

echo "Step: Merge FUNNY_LIST"
true > domain_funny.list
for site in "${FUNNY_LIST[@]}"; do
  if [[ "$site" == http://* || "$site" == https://* ]]; then
    url="$site"
  else
    url="https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/${site}.list"
  fi
  if ! curl -fsSL --retry 3 --connect-timeout 10 "$url" >> domain_funny.list; then
    echo "Warning: Download failed, skipped: $url" >&2
    continue
  fi
  echo >> domain_funny.list
done

echo "Step: Merge ASNList"
true > ipcidr_group.list
for asn in "${ASNLIST[@]}"; do
  file="dist/meta/asn/${asn}.list"
  if [ -f "$file" ]; then
    cat "$file" >> ipcidr_group.list
    echo >> ipcidr_group.list
  else
    echo "[WARN] missing ASN file: $file" >&2
  fi
done

echo "Step: dedupe"
sort -u domain_group.list -o dist/domain_group.list
sort -u ipcidr_group.list -o dist/ipcidr_group.list
sort -u domain_funny.list -o dist/domain_funny.list

echo "Step: convert to mrs"
./mihomo convert-ruleset domain text dist/domain_funny.list dist/domain_funny.mrs
./mihomo convert-ruleset domain text dist/domain_group.list dist/domain_group.mrs
./mihomo convert-ruleset ipcidr text dist/ipcidr_group.list dist/ipcidr_group.mrs

echo ">>> build Dat"
buildGeoASN
buildGeoEU
split_rules "1.list" "lite-ip.list" "lite-domain/lite"
go run -C geoip ./ convert -c ../lite-ip.json
go run -C community/ ./ --datapath=../lite-domain --outputdir ../dist --outputname lite-domain.dat

echo "==== ALL DONE ===="
