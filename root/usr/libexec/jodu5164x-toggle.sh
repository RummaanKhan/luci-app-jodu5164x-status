#!/bin/sh

UCI_PKG="jodu5164x"

uci set ${UCI_PKG}.main.enabled="$1"
uci commit ${UCI_PKG}

if [ "$1" = "0" ]; then
    rm -f /tmp/jodu5164x_cookie.txt
fi

echo "OK"
