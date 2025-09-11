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
cat > ~/.config/pulse/client.conf << 'EOF'
default-server = unix:/run/user/1000/pulse/native
autospawn = yes
enable-shm = yes
EOF

cat > ~/.config/pulse/daemon.conf << 'EOF'
exit-idle-time = -1
flat-volumes = no
EOF
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

# PulseAudio 데몬을 포그라운드로 시작해서 초기화 확인
timeout 10s pulseaudio --start --log-target=stderr -v || true
sleep 2

# 백그라운드로 다시 시작
pulseaudio --start --log-target=syslog
sleep 3

# 연결 테스트
if pactl info >/dev/null 2>&1; then
    echo '✓ PulseAudio 연결 성공'
    pactl info | head -5
else
    echo '✗ PulseAudio 연결 실패 - 수동으로 다시 시도합니다'
    
    # 다시 한 번 시도
    pulseaudio --kill 2>/dev/null || true
    sleep 2
    pulseaudio --start -v
    sleep 3
    
    if pactl info >/dev/null 2>&1; then
        echo '✓ PulseAudio 두 번째 시도 성공'
    else
        echo '✗ PulseAudio 연결 여전히 실패'
        echo '  다음 명령어로 수동 확인:'
        echo '  docker exec -it $CONTAINER_NAME su - kbs'
        echo '  export XDG_RUNTIME_DIR=/run/user/1000'
        echo '  pactl info'
    fi
fi
"

echo "=== 완료 ==="
echo "PulseAudio 환경 설정이 완료되었습니다."
echo "이제 container_audio_setting.sh를 실행해보세요."