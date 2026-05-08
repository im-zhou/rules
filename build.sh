#!/usr/bin/env bash
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
  "AS8075"    # Azure
  "AS396982"  # GCP
  "AS16509"   # AWS
  "AS398810"  # MXroute
  "AS13238"   # Yandex
  "AS42960"   # VH Global Limited
)

echo "Step: Download mihomo"
download_mihomo

echo "Step: Merge DomainList"
> domain_group.list
for site in "${DOMAIN_URLS[@]}"; do
  curl -sL --retry 3 --connect-timeout 10 "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite/$site.list" >> domain_group.list
  echo >> domain_group.list
done

echo "Step: Build ASN from GeoLite2-ASN"
mkdir -p dist/meta/asn
wget -qO ./convert/GeoLite2-ASN.mmdb https://raw.githubusercontent.com/Loyalsoldier/geoip/release/GeoLite2-ASN.mmdb
go run -C convert/ ./ asn -o ../dist/meta/asn

echo "Step: Merge ASNList"
> ipcidr_group.list
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

echo "Step: convert to mrs"
./mihomo convert-ruleset domain text dist/domain_group.list dist/domain_group.mrs
./mihomo convert-ruleset ipcidr text dist/ipcidr_group.list dist/ipcidr_group.mrs

echo "==== ALL DONE ===="
