#!/usr/bin/env bash
. ./conf.sh
. ./eu.sh
set -euo pipefail

# VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep tag_name | cut -d '"' -f4)
# echo "Using mihomo $VERSION"
# wget -O - https://github.com/MetaCubeX/mihomo/releases/download/${VERSION}/mihomo-linux-amd64-v1-${VERSION}.gz | gunzip > mihomo
# chmod +x mihomo

download_mihomo() {
    local max_retries="${1:-5}"
    local retry_delay="${2:-3}"
    local version
    local i
    get_version() {
        curl -fsSL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep tag_name | cut -d '"' -f4
    }
    do_download() {
        local ver="$1"
        wget -qO - "https://github.com/MetaCubeX/mihomo/releases/download/${ver}/mihomo-linux-amd64-v1-${ver}.gz" | gunzip > mihomo
    }
    for ((i=1; i<=max_retries; i++)); do
        echo "[$i/$max_retries] Fetching latest mihomo version..."
        version="$(get_version || true)"
        if [[ -z "${version}" ]]; then
            echo "Failed to get version, retrying in ${retry_delay}s..."
            sleep "${retry_delay}"
            continue
        fi
        echo "Using mihomo ${version}"
        if do_download "${version}"; then
            chmod +x mihomo
            echo "mihomo downloaded successfully"
            return 0
        fi
        echo "Download failed, retrying in ${retry_delay}s..."
        rm -f mihomo
        sleep "${retry_delay}"
    done
    echo "Failed to download mihomo after ${max_retries} attempts"
    return 1
}

# https://github.com/MetaCubeX/meta-rules-dat/tree/meta

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
  curl -sL --retry 3 --connect-timeout 10 "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/$site.list" >> domain_funny.list
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

function buildGeoASN() {
echo ">>> generate geoasn.json"
cat > geoasn.json <<EOF
{
  "input": [
EOF
FIRST=1
#
# ASN -> DAT 分集
#
for asn in "${ASNLIST[@]}"; do
  FILE="dist/meta/asn/${asn}.list"
  [ -f "$FILE" ] || continue
  NAME=$(echo "$asn" | tr '[:upper:]' '[:lower:]')
  if [ $FIRST -eq 0 ]; then
    echo "," >> geoasn.json
  fi
  FIRST=0
  cat >> geoasn.json <<EOF
{
  "type": "text",
  "action": "add",
  "args": {
    "name": "$NAME",
    "uri": "../$FILE"
  }
}
EOF
done
cat >> geoasn.json <<EOF
  ],
  "output": [
    {
      "type": "v2rayGeoIPDat",
      "action": "output",
      "args": {
        "outputDir": "../dist",
        "outputName": "geoasn.dat"
      }
    }
  ]
}
EOF
go run -C geoip ./ convert -c ../geoasn.json
}

function buildGeoEU() {
echo ">>> generate geoeu.json"
cat > geoeu.json <<EOF
{
  "input": [
EOF
#
# GeoIP -> DAT 欧洲国家合集
#
FIRST=1
for cc in "${EULIST[@]}"; do
  FILE="dist/meta/geoip/${cc,,}.list"
  [ -f "$FILE" ] || continue
  if [ $FIRST -eq 0 ]; then
    echo "," >> geoeu.json
  fi
  FIRST=0
  cat >> geoeu.json <<EOF
{
  "type": "text",
  "action": "add",
  "args": {
    "name": "eu",
    "uri": "../$FILE"
  }
}
EOF
done
cat >> geoeu.json <<EOF
  ],
  "output": [
    {
      "type": "v2rayGeoIPDat",
      "action": "output",
      "args": {
        "outputDir": "../dist",
        "outputName": "geoeu.dat"
      }
    }
  ]
}
EOF
go run -C geoip ./ convert -c ../geoeu.json
}

echo ">>> build GeoDat"
buildGeoASN
buildGeoEU

echo "==== ALL DONE ===="
