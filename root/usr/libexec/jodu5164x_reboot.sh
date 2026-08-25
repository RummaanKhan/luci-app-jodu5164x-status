#!/bin/sh
# /usr/libexec/jodu5164x_reboot.sh - Safely reboots JODU5164x ODU

IP=$(/sbin/uci -q get jodu5164x.main.ip || echo "192.168.225.1")
USER=$(/sbin/uci -q get jodu5164x.main.user)
PASS=$(/sbin/uci -q get jodu5164x.main.pass)

(
    if [ -n "$USER" ] && [ "$USER" != "none" ]; then
        sleep 2
        echo "$USER"
        sleep 2
        echo "$PASS"
        sleep 2
    else
        sleep 1
        echo ""
        sleep 1
    fi
    echo "reboot"
    sleep 2
    echo "exit"
    sleep 2
) | nc "$IP" 23 >/dev/null 2>&1 &

TELNET_PID=$!
sleep 15
kill -9 $TELNET_PID 2>/dev/null
killall -9 nc 2>/dev/null
