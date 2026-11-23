#!/bin/sh

IP=$(/sbin/uci -q get jodu5164x.main.ip)
[ -z "$IP" ] && IP=$(/sbin/uci -q get jodu5164x.main.host)
[ -z "$IP" ] && IP="192.168.225.1"
USER=$(/sbin/uci -q get jodu5164x.main.user)
[ -z "$USER" ] && USER=$(/sbin/uci -q get jodu5164x.main.telnet_username)
PASS=$(/sbin/uci -q get jodu5164x.main.pass)
[ -z "$PASS" ] && PASS=$(/sbin/uci -q get jodu5164x.main.telnet_password)

OUTPUT=$( (
    if [ -n "$PASS" ]; then
        sleep 1
        printf '%s\r\n' "$PASS"
        sleep 1
    else
        sleep 1
        printf '\r\n'
        sleep 1
    fi
    printf 'NRCELLH=$(timeout 8 /usr/bin/atcli "AT+BNRCELLH" 2>/dev/null); echo "$NRCELLH" > /tmp/www/neighbors.txt; echo "===SCAN_DATA==="; echo "$NRCELLH"; echo "===END_SCAN==="\r\n'
    sleep 3
    printf 'exit\r\n'
    sleep 1
) | nc "$IP" 23 2>/dev/null )

RAW_CELLS=$(echo "$OUTPUT" | sed -n '/===SCAN_DATA===/,/===END_SCAN===/p' | grep -v '===')

NEIGHBORS_JSON=$(printf '%s\n' "$RAW_CELLS" | tr -d '\r' | awk '
    BEGIN { printf "["; first=1 }
    NF==5 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+$/ {
        arfcn=$2; pci=$3; rsrp=$4; rsrq=$5
        if (arfcn == "0" && pci == "0") next
        band="n78"
        if (arfcn < 200000) band="n28"
        if (arfcn > 2000000) band="n258"
        if (!first) printf ","
        printf "{\"pci\":\"%s\",\"arfcn\":\"%s\",\"rsrp\":\"%s\",\"rsrq\":\"%s\",\"band\":\"%s\"}", pci, arfcn, rsrp, rsrq, band
        first = 0
    }
    END { printf "]" }
')
[ -z "$NEIGHBORS_JSON" ] && NEIGHBORS_JSON="[]"

printf '{"status":"success","neighbors":%s}\n' "$NEIGHBORS_JSON"
