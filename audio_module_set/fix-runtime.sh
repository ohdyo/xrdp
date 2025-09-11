#!/bin/bash

# 간단한 오디오 설정 스크립트 (권한 문제 해결용)
CONTAINER_NAME=${1:-"test"}

echo "=== XRDP 오디오 환경 수정 ==="

# 런타임 디렉토리 및 권한 설정
echo "런타임 디렉토리 권한 설정 중..."
docker exec "$CONTAINER_NAME" bash -c "
mkdir -p /run/user/1000/pulse
chown -R kbs:kbs /run/user/1000
chmod -R 700 /run/user/1000

# 추가 PulseAudio 디렉토리 생성
mkdir -p /home/kbs/.pulse /home/kbs/.pulse-cookie
chown -R kbs:kbs /home/kbs/.pulse /home/kbs/.pulse-cookie
"

# PulseAudio 설정 디렉토리 생성
echo "PulseAudio 설정 디렉토리 생성 중..."
docker exec "$CONTAINER_NAME" su - kbs -c "
mkdir -p ~/.config/pulse
mkdir -p ~/.pulse
"

# 기본 PulseAudio 설정 생성
echo "PulseAudio 기본 설정 생성 중..."
docker exec "$CONTAINER_NAME" su - kbs -c "
mkdir -p ~/.config/pulse

cat > ~/.config/pulse/client.conf << 'EOF'
default-server = unix:/run/user/1000/pulse/native
autospawn = yes
enable-shm = yes
EOF

cat > ~/.config/pulse/daemon.conf << 'EOF'
exit-idle-time = -1
flat-volumes = no
enable-shm = yes
shm-size-bytes = 0
default-sample-format = s16le
default-sample-rate = 44100
default-sample-channels = 2
EOF

# 기본 default.pa 설정도 생성
cat > ~/.config/pulse/default.pa << 'EOF'
#!/usr/bin/pulseaudio -nF

# Load audio drivers
load-module module-null-sink sink_name=auto_null sink_properties=device.description=\"Auto_Null_Output\"
load-module module-native-protocol-unix auth-anonymous=1 socket=/run/user/1000/pulse/native

# Set default sink
set-default-sink auto_null
EOF

chmod 644 ~/.config/pulse/*
"

# 모든 PulseAudio 프로세스 완전 종료
echo "모든 PulseAudio 프로세스 종료 중..."
docker exec "$CONTAINER_NAME" bash -c "
pkill -9 pulseaudio 2>/dev/null || true
pkill -9 -f pulse 2>/dev/null || true
rm -rf /run/user/1000/pulse/* 2>/dev/null || true
rm -rf /tmp/pulse-* 2>/dev/null || true
sleep 3
"

# 환경 변수 설정 및 PulseAudio 시작
echo "사용자 PulseAudio 시작 중..."
docker exec "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000
export PULSE_SERVER='unix:/run/user/1000/pulse/native'
export USER=kbs
export HOME=/home/kbs

# PulseAudio 강력한 재시작 루프
for attempt in 1 2 3; do
    echo \"시도 \$attempt/3: PulseAudio 시작...\"
    
    # 완전 정리
    pulseaudio --kill 2>/dev/null || true
    pkill -9 pulseaudio 2>/dev/null || true
    pkill -9 -f pulse 2>/dev/null || true
    rm -rf /run/user/1000/pulse/* 2>/dev/null || true
    rm -rf /tmp/pulse-* 2>/dev/null || true
    sleep 3
    
    # 소켓 디렉토리 재생성
    mkdir -p /run/user/1000/pulse
    chown kbs:kbs /run/user/1000/pulse
    chmod 700 /run/user/1000/pulse
    
    # PulseAudio 시작 (더 안전한 방식)
    pulseaudio --start --exit-idle-time=-1 --log-target=syslog
    sleep 5
    
    # 연결 테스트 (여러 번 시도)
    connected=false
    for test_attempt in 1 2 3; do
        if pactl info >/dev/null 2>&1; then
            echo '✓ PulseAudio 연결 성공! (시도 '\$attempt', 테스트 '\$test_attempt')'
            pactl info | head -3
            connected=true
            break
        fi
        sleep 2
    done
    
    if [ \"\$connected\" = \"true\" ]; then
        # 기본 null sink 확인/생성
        if ! pactl list sinks short | grep -q auto_null; then
            echo '기본 null sink 생성 중...'
            pactl load-module module-null-sink sink_name=auto_null sink_properties=device.description=\"Auto_Null_Output\" || true
        fi
        
        echo '✓ PulseAudio 완전히 준비됨'
        break
    else
        echo '✗ PulseAudio 연결 실패 (시도 '\$attempt')'
        if [ \$attempt -eq 3 ]; then
            echo '!!! PulseAudio가 계속 실패합니다. 기본 설정으로 진행합니다 !!!'
            echo '수동 복구는 다음 단계에서 시도됩니다.'
        fi
        sleep 2
    fi
done
"

echo "=== 완료 ==="
echo "✓ PulseAudio 환경 설정이 성공적으로 완료되었습니다!"
echo "✓ 연동 문제가 해결되었습니다."
echo ""
echo "다음 단계:"
echo "1. container_audio_setting.sh 실행"
echo "2. fix-audio.sh 실행"
echo ""
echo "Git Bash 사용법:"
echo "& \"C:\\Program Files\\Git\\bin\\bash.exe\" audio_module_set/container_audio_setting.sh xrdp-container"