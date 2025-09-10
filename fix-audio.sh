#!/bin/bash

# 완전한 XRDP 오디오 수정 스크립트 - 최종 버전
# 사용법: ./fix-audio.sh [컨테이너명]

CONTAINER_NAME=${1:-"test-v3"}

echo "=================================================="
echo "XRDP 오디오 완전 수정 스크립트 - 최종 버전"
echo "컨테이너: $CONTAINER_NAME"
echo "=================================================="

# 1. 시스템 레벨 완전 정리 (root 권한으로)
echo "1단계: 시스템 레벨 완전 정리..."
docker exec -it "$CONTAINER_NAME" bash -c "
# 모든 PulseAudio 관련 프로세스 강제 종료 (zombie 포함)
echo '모든 PulseAudio 프로세스 강제 종료 중...'
pkill -9 -f pulseaudio 2>/dev/null || true
pkill -9 -f pavucontrol 2>/dev/null || true
pkill -9 -f pactl 2>/dev/null || true

# zombie 프로세스 정리를 위한 대기
sleep 5

# 시스템 전체 PulseAudio 관련 파일 정리
echo 'PulseAudio 관련 파일 정리 중...'
rm -rf /run/user/*/pulse* 2>/dev/null || true
rm -rf /tmp/.pulse* 2>/dev/null || true
rm -rf /tmp/pulse* 2>/dev/null || true
rm -rf /home/*/pulse* 2>/dev/null || true
rm -rf /home/*/.pulse* 2>/dev/null || true
rm -rf /home/*/.config/pulse 2>/dev/null || true

# 런타임 디렉토리 완전 재생성
echo '런타임 디렉토리 재생성 중...'
rm -rf /run/user/1000 2>/dev/null || true
mkdir -p /run/user/1000
chown kbs:kbs /run/user/1000
chmod 700 /run/user/1000

# 홈 디렉토리 권한 설정
chown -R kbs:kbs /home/kbs
chmod 755 /home/kbs

echo '시스템 정리 완료'
"

# 2. PulseAudio 사용자 환경 완전 재구성
echo "2단계: PulseAudio 사용자 환경 재구성..."
docker exec -it "$CONTAINER_NAME" su - kbs -c "
echo 'PulseAudio 사용자 환경 설정 중...'

# 환경 변수 설정
export XDG_RUNTIME_DIR=/run/user/1000
export PULSE_RUNTIME_PATH=/run/user/1000/pulse
export PULSE_CONFIG_DIR=~/.config/pulse

# PulseAudio 설정 디렉토리 생성
mkdir -p ~/.config/pulse
mkdir -p ~/.cache/pulse
chmod 700 ~/.config/pulse
chmod 700 ~/.cache/pulse

# 최소한의 클린 설정 파일 생성
cat > ~/.config/pulse/default.pa << 'EOF'
# 기본 설정 포함
.include /etc/pulse/default.pa

# XRDP 모듈 로드
load-module module-xrdp-sink
load-module module-xrdp-source

# 기본 장치 설정
set-default-sink xrdp-sink
set-default-source xrdp-source
EOF

# 클라이언트 설정
cat > ~/.config/pulse/client.conf << 'EOF'
default-sink = xrdp-sink
default-source = xrdp-source
autospawn = yes
EOF

chmod 644 ~/.config/pulse/default.pa
chmod 644 ~/.config/pulse/client.conf

echo 'PulseAudio 설정 파일 생성 완료'
"

# 3. PulseAudio 안전한 시작
echo "3단계: PulseAudio 안전한 시작..."
docker exec -it "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000
export PULSE_RUNTIME_PATH=/run/user/1000/pulse

echo 'PulseAudio 데몬 시작 중...'

# 여러 시도로 안전하게 시작
for attempt in 1 2 3; do
    echo \"시도 \$attempt/3: PulseAudio 시작...\"
    
    # 이전 시도의 잔여물 정리
    pulseaudio --kill 2>/dev/null || true
    sleep 3
    
    # PulseAudio 시작
    if pulseaudio --start --log-target=stderr; then
        echo 'PulseAudio 시작 성공!'
        sleep 5
        
        # 연결 테스트
        if pactl info >/dev/null 2>&1; then
            echo 'PulseAudio 연결 성공!'
            break
        else
            echo 'PulseAudio 연결 실패, 재시도...'
        fi
    else
        echo 'PulseAudio 시작 실패, 재시도...'
    fi
    
    if [ \$attempt -eq 3 ]; then
        echo 'PulseAudio 시작 최종 실패'
        exit 1
    fi
    
    sleep 5
done
"

# 4. XRDP 모듈 로드 및 설정
echo "4단계: XRDP 모듈 로드 및 설정..."
docker exec -it "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000

if pactl info >/dev/null 2>&1; then
    echo 'XRDP 모듈 로드 중...'
    
    # 기존 XRDP 모듈 정리
    pactl list modules short | grep xrdp | cut -f1 | while read module_id; do
        echo \"기존 XRDP 모듈 \$module_id 언로드 중...\"
        pactl unload-module \$module_id 2>/dev/null || true
    done
    
    sleep 3
    
    # XRDP 모듈 로드
    echo 'XRDP Sink 모듈 로드...'
    SINK_MODULE=\$(pactl load-module module-xrdp-sink 2>/dev/null)
    if [ -n \"\$SINK_MODULE\" ]; then
        echo \"XRDP Sink 모듈 로드 성공 (ID: \$SINK_MODULE)\"
    else
        echo 'XRDP Sink 모듈 로드 실패'
    fi
    
    echo 'XRDP Source 모듈 로드...'
    SOURCE_MODULE=\$(pactl load-module module-xrdp-source 2>/dev/null)
    if [ -n \"\$SOURCE_MODULE\" ]; then
        echo \"XRDP Source 모듈 로드 성공 (ID: \$SOURCE_MODULE)\"
    else
        echo 'XRDP Source 모듈 로드 실패'
    fi
    
    sleep 3
    
    # 기본 장치 설정
    echo '기본 장치 설정...'
    if pactl list sinks short | grep -q xrdp-sink; then
        pactl set-default-sink xrdp-sink && echo 'XRDP Sink을 기본으로 설정 완료'
    fi
    
    if pactl list sources short | grep -q xrdp-source; then
        pactl set-default-source xrdp-source && echo 'XRDP Source를 기본으로 설정 완료'
    fi
    
else
    echo 'PulseAudio 연결 실패 - 설정을 건너뛸 수 없음'
    exit 1
fi
"

# 5. Volume Control 및 GUI 애플리케이션 재시작
echo "5단계: Volume Control 재시작..."
docker exec -it "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000
export DISPLAY=:10

echo 'Volume Control 애플리케이션 재시작 중...'

# 기존 pavucontrol 프로세스 완전 종료
pkill -9 -f pavucontrol 2>/dev/null || true
sleep 3

# 새로운 환경에서 pavucontrol 시작
nohup pavucontrol >/dev/null 2>&1 &
sleep 2

echo 'Volume Control 재시작 완료'
"

# 6. 최종 상태 확인
echo ""
echo "6단계: 최종 상태 확인..."
echo "------------------------------------------------------"

echo "PulseAudio 데몬 상태:"
docker exec -it "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000
if pactl info >/dev/null 2>&1; then
    echo 'PulseAudio: 정상 작동 중'
    ps aux | grep pulseaudio | grep -v defunct | grep -v grep | head -3
else
    echo 'PulseAudio: 연결 실패'
fi
"

echo ""
echo "현재 오디오 장치:"
docker exec -it "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000
echo '--- 출력 장치 ---'
pactl list sinks short 2>/dev/null || echo '출력 장치 조회 실패'
echo '--- 입력 장치 ---'
pactl list sources short 2>/dev/null || echo '입력 장치 조회 실패'
"

echo ""
echo "기본 장치 설정:"
docker exec -it "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000
pactl info 2>/dev/null | grep -E 'Default Sink|Default Source|기본 싱크|기본 소스' || echo '기본 장치 정보 조회 실패'
"

echo ""
echo "=================================================="
echo "XRDP 오디오 수정 완료!"
echo "=================================================="
echo ""
echo "이제 원격 데스크톱에서 Volume Control을 확인해보세요."
echo "여전히 문제가 있다면:"
echo "1. 원격 데스크톱 연결을 새로 시작하세요"
echo "2. Volume Control을 닫고 다시 열어보세요"
echo ""
echo "정상 작동하면 다음 명령어로 이미지를 저장하세요:"
echo "docker commit $CONTAINER_NAME xrdp-korean-audio-final:latest"
echo ""