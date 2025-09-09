#!/bin/bash

# 환경 변수 로드
if test -r /etc/profile; then
    . /etc/profile
fi

if test -r /etc/default/locale; then
    . /etc/default/locale
    test -z "${LANG+x}" || export LANG
    test -z "${LANGUAGE+x}" || export LANGUAGE
    test -z "${LC_ALL+x}" || export LC_ALL
fi

# XRDP 사용자 세션 시작 스크립트 (기본 버전)
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

echo "[startwm] Starting XRDP user session..."
echo "[startwm] User: $(whoami), UID: $(id -u)"

# 런타임 디렉토리 설정
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"
fi

# PulseAudio 설정 및 시작
echo "[startwm] Setting up PulseAudio..."
export PULSE_RUNTIME_PATH="$XDG_RUNTIME_DIR/pulse"
mkdir -p "$PULSE_RUNTIME_PATH"

# PulseAudio 데몬 시작
pulseaudio --start --log-target=syslog 2>/dev/null || true
sleep 2

# 기본 오디오 싱크 생성
pactl load-module module-null-sink sink_name=virtual_output sink_properties=device.description="Virtual_Audio_Output" 2>/dev/null || true
pactl set-default-sink virtual_output 2>/dev/null || true

# 네트워크 프로토콜 활성화 (RDP 오디오 지원)
pactl load-module module-native-protocol-tcp auth-anonymous=1 port=4713 2>/dev/null || true

echo "[startwm] Audio setup completed"

echo "[startwm] Starting XFCE desktop environment..."

# XFCE 데스크톱 시작
exec startxfce4
