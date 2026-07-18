#!/usr/bin/env bash

# VERSION=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep tag_name | cut -d '"' -f4)
# echo "Using mihomo $VERSION"
# wget -O - https://github.com/MetaCubeX/mihomo/releases/download/${VERSION}/mihomo-linux-amd64-v1-${VERSION}.gz | gunzip > mihomo
# chmod +x mihomo

function download_mihomo() {
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

function split_rules() {
    local input="$1"
    local ip_out="${2:-lite-ip.list}"
    local domain_out="${3:-lite-domain.list}"
    mkdir -p "$(dirname "$ip_out")" "$(dirname "$domain_out")"
    : > "$ip_out"
    : > "$domain_out"
    awk -v ip="$ip_out" -v domain="$domain_out" '
    /^[[:space:]]*$/ || /^[[:space:]]*#/ { next }
    /^IP-CIDR,/ {
        split($0, a, ",")
        print a[2] >> ip
        next
    }
    /^IP-CIDR6,/ {
        split($0, a, ",")
        print a[2] >> ip
        next
    }
    {
        print >> domain
    }
    ' "$input"
    grep DOMAIN "$domain_out" | grep -v "#" \
    | sed 's/^DOMAIN,/full:/g' \
    | sed 's/^DOMAIN-SUFFIX,//g' \
    | sed 's/^DOMAIN-KEYWORD,/keyword:/g' \
    > "${domain_out}.tmp" && mv "${domain_out}.tmp" "$domain_out"
}
