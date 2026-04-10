#### install:
```bash
go install -v github.com/Loyalsoldier/geoip@latest
```

#### convert:
```bash
geoip convert
```

#### use:
```json
{
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "outboundTag": "direct",
        "ip": [
          "ext:mygeoip.dat:oracle",
          "ext:mygeoip.dat:rfchost",
          "63.223.84.0/24"
        ]
      }
    ]
  }
}
```
