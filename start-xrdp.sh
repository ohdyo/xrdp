#!/bin/bash
set -euo pipefail

ln -sf /usr/local/bin/startwm.sh /etc/xrdp/startwm.sh

echo "[start-xrdp] USER: ${USER_NAME:-} UID: $(id -u ${USER_NAME:-} 2>/dev/null || echo n/a)" || true
echo "[start-xrdp] Starting XRDP services..."

# 사용자 홈 디렉토리 권한 확인
echo "[start-xrdp] Setting up user directories..."
mkdir -p /home/${USER_NAME:-kbs}/.cache /home/${USER_NAME:-kbs}/.config
chown -R ${USER_NAME:-kbs}:${USER_NAME:-kbs} /home/${USER_NAME:-kbs}

# PulseAudio 시스템 준비
echo "[start-xrdp] Preparing audio system..."
mkdir -p /run/user/1000/pulse
chown -R ${USER_NAME:-kbs}:${USER_NAME:-kbs} /run/user/1000 2>/dev/null || true

echo "[start-xrdp] Starting XRDP sesman..."
/usr/sbin/xrdp-sesman &
sleep 2

echo "[start-xrdp] Starting XRDP daemon..."
exec /usr/sbin/xrdp -nodaemon