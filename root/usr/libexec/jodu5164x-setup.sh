#!/bin/sh

touch /tmp/odu5164x_setup.lock
trap 'rm -f /tmp/odu5164x_setup.lock' EXIT INT TERM HUP

IP=$(/sbin/uci -q get jodu5164x.main.ip || echo "192.168.225.1")
USER=$(/sbin/uci -q get jodu5164x.main.user)
PASS=$(/sbin/uci -q get jodu5164x.main.pass)

NR_ARFCN=$(/sbin/uci -q get jodu5164x.main.arfcn)
NR_PCI=$(/sbin/uci -q get jodu5164x.main.pci)

(
# Authenticate only if password is configured
if [ -n "$PASS" ]; then
    sleep 2
    printf '%s\r\n' "$PASS"
    sleep 2
else
    sleep 1
    printf '\r\n'
    sleep 1
fi

# Apply Cell Lock if configured (using 2.5 proven syntax)
if [ -n "$NR_ARFCN" ] && [ -n "$NR_PCI" ]; then
    printf 'cricli set_nr5g_cell_config 0 %s %s 1 0 8192 0 0 0 0 0 0\r\n' "$NR_PCI" "$NR_ARFCN"
    sleep 2
fi

# Stop any previous monitor loop in /tmp/ (kill all instances)
echo "kill -9 \$(cat /tmp/odu_monitor.pid 2>/dev/null) 2>/dev/null"
echo "killall -9 odu_monitor.sh 2>/dev/null"
echo "pkill -9 -f odu_monitor 2>/dev/null"
echo "rm -f /tmp/odu_monitor.pid"
sleep 1

# Deploy lightweight, non-invasive monitor loop completely in /tmp/
echo "cat << 'EOF' > /tmp/odu_monitor.sh"
echo "#!/bin/sh"
echo "echo \$\$ > /tmp/odu_monitor.pid"
echo "mkdir -p /tmp/www"
echo "COUNT=0"
echo "while true; do"
echo "    if ! pidof httpd > /dev/null; then"
echo "        httpd -p 8080 -h /tmp/www"
echo "    fi"
echo "    if [ \$((COUNT % 10)) -eq 0 ]; then"
echo "        [ -x /usr/bin/atcli ] && NRINFO=\$(/usr/bin/atcli \"AT+BNRINFO\" 2>/dev/null)"
echo "        sleep 0.2"
echo "        [ -x /usr/bin/atcli ] && NRCAINFO=\$(/usr/bin/atcli \"AT+NRCAINFO\" 2>/dev/null)"
echo "        sleep 0.2"
echo "        [ -x /usr/bin/atcli ] && NRCELLH=\$(/usr/bin/atcli \"AT+BNRCELLH\" 2>/dev/null)"
echo "        sleep 0.2"
echo "    fi"
echo "    COUNT=\$((COUNT + 1))"
echo "    CRI_CELL=\"\""
echo "    command -v cricli >/dev/null 2>&1 && CRI_CELL=\$(cricli cell_location 2>/dev/null)"
echo "    CRI_BAND=\"\""
echo "    command -v cricli >/dev/null 2>&1 && CRI_BAND=\$(cricli band 2>/dev/null)"
echo "    read p_total p_idle < /tmp/odu_cpu_stat 2>/dev/null"
echo "    CPU=\$(awk -v pt=\"\${p_total:-0}\" -v pi=\"\${p_idle:-0}\" '/^cpu / { t=\$2+\$3+\$4+\$5+\$6+\$7+\$8+\$9; i=\$5; dt=t-pt; di=i-pi; if(pt>0 && dt>0) print int(100*(dt-di)/dt); else print \"0\"; print t\" \"i > \"/tmp/odu_cpu_stat\"; exit }' /proc/stat)"
echo "    TEMP=\$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo \"0\")"
echo "    NET_BYTES=\$(cricli wwan_stats 2>/dev/null | grep -i 'IPV4' | head -n1 | sed -n 's/.*bytes: ( \\([0-9]*\\) \\/ \\([0-9]*\\) ).*/\\2 \\1/p')"
echo "    [ -z \"\$NET_BYTES\" ] && NET_BYTES=\"\$(cat /sys/class/net/rmnet_data0/statistics/rx_bytes 2>/dev/null || echo \"0\") \$(cat /sys/class/net/rmnet_data0/statistics/tx_bytes 2>/dev/null || echo \"0\")\""
echo "    {"
echo "        echo \"---BNRINFO---\""
echo "        echo \"\$NRINFO\""
echo "        echo \"---NRCAINFO---\""
echo "        echo \"\$NRCAINFO\""
echo "        echo \"---CRI_CELL---\""
echo "        echo \"\$CRI_CELL\""
echo "        echo \"---CRI_BAND---\""
echo "        echo \"\$CRI_BAND\""
echo "        echo \"---BNRCELLH---\""
echo "        echo \"\$NRCELLH\""
echo "        echo \"---CPU---\""
echo "        echo \"\${CPU:-0}\""
echo "        echo \"---TEMP---\""
echo "        echo \"\$TEMP\""
echo "        echo \"---NET---\""
echo "        echo \"\$NET_BYTES\""
echo "        echo \"---UPTIME---\""
echo "        cat /proc/uptime"
echo "        echo \"---MODEL---\""
echo "        if [ -f /usr/etc/versions/product_name ]; then cat /usr/etc/versions/product_name 2>/dev/null; else cat /proc/device-tree/model 2>/dev/null || echo \"JODU5164x\"; fi"
echo "        echo \"---VERSION---\""
echo "        echo \"5164x-1.0.0\""
echo "    } > /tmp/www/status.tmp"
echo "    mv /tmp/www/status.tmp /tmp/www/status.txt"
echo "    sleep 1"
echo "done"
echo "EOF"
sleep 1

echo "chmod +x /tmp/odu_monitor.sh"
sleep 1
echo "/tmp/odu_monitor.sh >/dev/null 2>&1 &"
sleep 1
echo "exit"
sleep 1
) | nc "$IP" 23 > /tmp/odu5164x_setup.log 2>&1 &

TELNET_PID=$!
sleep 25
kill -9 $TELNET_PID 2>/dev/null
killall -9 nc 2>/dev/null
