#!/bin/bash

# XRDP 오디오 설정 자동화 스크립트
# 사용법: ./container_audio_setting.sh [컨테이너명]
# 예시: ./container_audio_setting.sh test

# 컨테이너 이름 설정
CONTAINER_NAME=${1:-"test"}

echo "=================================================="
echo "XRDP 오디오 모듈 설정 스크립트"
echo "컨테이너: $CONTAINER_NAME"
echo "=================================================="

# 컨테이너 실행 상태 확인
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "오류: 컨테이너 '$CONTAINER_NAME'이 실행되지 않았습니다."
    echo "컨테이너를 먼저 실행해주세요:"
    echo "docker run -d -p 3389:3389 --name $CONTAINER_NAME [이미지명]"
    exit 1
fi

echo "컨테이너 '$CONTAINER_NAME' 확인됨"

# 1단계: 컨테이너 내에서 XRDP 오디오 모듈 설정하기
echo ""
echo "1단계: 컨테이너 내에서 XRDP 오디오 모듈 설정하기"
echo "------------------------------------------------------"

# 필요한 패키지 설치 및 업데이트
echo "필요한 패키지 설치 중..."
docker exec -it "$CONTAINER_NAME" bash -c "
apt-get update && apt-get install -y \
    git build-essential autotools-dev autoconf libtool libpulse-dev \
    meson ninja-build wget cmake pkg-config libsndfile1-dev \
    automake intltool libdbus-1-dev libglib2.0-dev \
    libcap-dev libsystemd-dev libavahi-client-dev \
    libasyncns-dev libbluetooth-dev libfftw3-dev \
    libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    libjack-jackd2-dev liborc-0.4-dev libsbc-dev \
    libsoxr-dev libspeexdsp-dev libtdb-dev libwebrtc-audio-processing-dev \
    libx11-xcb-dev libxcb1-dev libxtst6
"

# 소스 저장소 추가
echo "소스 저장소 추가 중..."
docker exec -it "$CONTAINER_NAME" bash -c "
echo 'deb-src http://archive.ubuntu.com/ubuntu jammy main' >> /etc/apt/sources.list
apt-get update
"

# PulseAudio 소스 다운로드 및 빌드
echo "PulseAudio 소스 다운로드 및 빌드 중..."
docker exec -it "$CONTAINER_NAME" bash -c "
apt-get update && apt-get build-dep -y pulseaudio
cd /tmp && apt-get source pulseaudio
cd pulseaudio-15.99.1+dfsg1 && meson build
ninja -C build
"

# XRDP 모듈 다운로드 및 컴파일
echo "XRDP 모듈 다운로드 및 컴파일 중..."
docker exec -it "$CONTAINER_NAME" bash -c "
cd /tmp && git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
cd pulseaudio-module-xrdp && ./bootstrap && ./configure PULSE_DIR=/tmp/pulseaudio-15.99.1+dfsg1 PULSE_CONFIG_DIR=/tmp/pulseaudio-15.99.1+dfsg1/build
make
"

# 모듈 설치
echo "XRDP 모듈 설치 중..."
docker exec -it "$CONTAINER_NAME" bash -c "
cd /tmp/pulseaudio-module-xrdp && make install
"

echo ""
echo "2단계: 사용자로 PulseAudio 재시작 및 XRDP 모듈 로드"
echo "------------------------------------------------------"

# PulseAudio 종료 및 재시작
echo "PulseAudio 재시작 중..."
docker exec -it "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000
mkdir -p /run/user/1000
chmod 700 /run/user/1000
pulseaudio --kill 2>/dev/null || true
pulseaudio --start
"

# XRDP 모듈 로드
echo "XRDP 모듈 로드 중..."
docker exec -it "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000
pactl load-module module-xrdp-sink
pactl load-module module-xrdp-source
"

# 기본 오디오 장치 설정
echo "기본 오디오 장치를 XRDP로 설정 중..."
docker exec -it "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000
pactl set-default-sink xrdp-sink
pactl set-default-source xrdp-source
"

# 현재 오디오 설정 확인
echo "현재 오디오 설정 확인:"
docker exec -it "$CONTAINER_NAME" su - kbs -c "
export XDG_RUNTIME_DIR=/run/user/1000
pactl info | grep -E '기본 싱크|기본 소스|Default Sink|Default Source'
"

# 사용자 설정 파일 생성
echo ""
echo "3단계: 사용자 설정 파일 생성"
echo "------------------------------------------------------"

echo "PulseAudio 자동 설정 파일 생성 중..."
docker exec -it "$CONTAINER_NAME" su - kbs -c "
mkdir -p ~/.config/pulse
cat > ~/.config/pulse/default.pa << 'EOF'
.include /etc/pulse/default.pa
load-module module-xrdp-sink
load-module module-xrdp-source
set-default-sink xrdp-sink
set-default-source xrdp-source
EOF
"

echo "VLC 오디오 설정 파일 생성 중..."
docker exec -it "$CONTAINER_NAME" su - kbs -c "
mkdir -p ~/.config/vlc
echo 'aout=pulse' > ~/.config/vlc/vlcrc
"

echo ""
echo "=================================================="
echo "XRDP 오디오 설정 완료!"
echo "=================================================="
echo ""
echo "설정을 영구적으로 저장하려면:"
echo "docker commit $CONTAINER_NAME xrdp-korean-audio:latest"
echo ""
