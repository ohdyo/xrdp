#!/bin/bash
set -euo pipefail

ln -sf /usr/local/bin/startwm.sh /etc/xrdp/startwm.sh

echo "[start-xrdp] USER: ${USER_NAME:-} UID: $(id -u ${USER_NAME:-} 2>/dev/null || echo n/a)" || true
echo "[start-xrdp] Starting XRDP services..."

# PulseAudio 시스템 준비
echo "[start-xrdp] Preparing audio system..."
mkdir -p /run/user/1000/pulse
chown -R ${USER_NAME:-kbs}:${USER_NAME:-kbs} /run/user/1000 2>/dev/null || true

echo "[start-xrdp] Starting XRDP daemon..."
/usr/sbin/xrdp-sesman

exec /usr/sbin/xrdp -nodaemon