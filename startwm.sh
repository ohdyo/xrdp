#!/bin/bash

export LANG=ko_KR.UTF-8
export LANGUAGE=ko_KR:ko
export LC_ALL=ko_KR.UTF-8

# 세션 로그 시작
echo "$(date): Starting session for user $USER" >> /tmp/session.log

if [ ! -d "$HOME/.cache" ]; then
    mkdir -p "$HOME/.cache"
fi

XDG_RUNTIME_DIR="/tmp/runtime-$USER"
export XDG_RUNTIME_DIR
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

# D-Bus 세션 시작
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
    export DBUS_SESSION_BUS_ADDRESS
    export DBUS_SESSION_BUS_PID
fi

# PulseAudio 시작
if ! pgrep -x "pulseaudio" > /dev/null; then
    pulseaudio --start --log-target=syslog &
    sleep 2
    for i in {1..10}; do
        if pactl info >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
fi

echo "$(date): Starting XFCE4" >> /tmp/session.log
exec startxfce4