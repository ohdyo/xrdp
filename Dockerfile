FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive \
	TZ=Etc/UTC \
	USER_NAME=kbs \
	USER_UID=1000 \
	USER_GID=1000 \
	USER_PASSWORD=asdf0110 \
	LANG=ko_KR.UTF-8 \
	LANGUAGE=ko_KR:ko \
	LC_ALL=ko_KR.UTF-8

# 1) 기본 패키지 및 supervisor 설치
RUN set -eux; \
    apt-get update; \
    apt-get install -y \
        supervisor \
        xfce4 xfce4-goodies xfce4-settings xfconf \
        xrdp xorgxrdp dbus-x11 x11-xserver-utils \
        mesa-utils xvfb \
        xserver-xorg-core xserver-xorg-input-all \
        at-spi2-core

# 2) 한국어/로케일 및 폰트 패키지
RUN set -eux; \
    apt-get update; \
    apt-get install -y\
        locales language-pack-ko fonts-noto-cjk fonts-noto-color-emoji fonts-nanum; \
    locale-gen ko_KR.UTF-8 en_US.UTF-8; \
    update-locale LANG=ko_KR.UTF-8 LANGUAGE=ko_KR:ko LC_ALL=ko_KR.UTF-8;

# 3) 이미지/영상 썸네일 및 미디어 태그/코덱/GVFS 관련 패키지
RUN set -eux; \
    apt-get update; \
    apt-get install -y \
        tumbler ffmpegthumbnailer thunar-media-tags-plugin \
        gstreamer1.0-libav gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
        gvfs gvfs-backends gvfs-fuse

# 4) 오디오, VLC 기본 패키지만 설치
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        pulseaudio pulseaudio-utils pavucontrol xfce4-pulseaudio-plugin vlc; \
    rm -rf /var/lib/apt/lists/*;

COPY ./startwm.sh /usr/local/bin/startwm.sh
COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 5) 시스템 설정 및 사용자 생성
RUN set -eux; \
    chmod +x /usr/local/bin/startwm.sh; \
    ln -sf /usr/local/bin/startwm.sh /etc/xrdp/startwm.sh; \
    # 기존 사용자 정리
    if id -u ${USER_UID} >/dev/null 2>&1; then \
        userdel $(id -nu ${USER_UID}) 2>/dev/null || true; \
    fi; \
    if getent group ${USER_GID} >/dev/null 2>&1; then \
        groupdel $(getent group ${USER_GID} | cut -d: -f1) 2>/dev/null || true; \
    fi; \
    if getent group ${USER_NAME} >/dev/null 2>&1; then \
        groupdel ${USER_NAME} 2>/dev/null || true; \
    fi; \
    # 새로운 그룹과 사용자 생성
    groupadd -g ${USER_GID} ${USER_NAME}; \
    useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash ${USER_NAME}; \
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd; \
    adduser xrdp ssl-cert; \
    groupadd -f tsusers; \
    usermod -a -G tsusers ${USER_NAME}; \
    usermod -a -G audio ${USER_NAME}; \
    # 디렉토리 및 권한 설정
    mkdir -p /var/run/xrdp /var/log/xrdp /var/log/supervisor; \
    chmod 755 /var/run/xrdp /var/log/xrdp /var/log/supervisor; \
    chown xrdp:xrdp /var/run/xrdp; \
    # X11 권한 설정
    echo "allowed_users=anybody" >> /etc/X11/Xwrapper.config; \
    echo "needs_root_rights=yes" >> /etc/X11/Xwrapper.config; \
    # 사용자 설정 디렉토리 미리 생성
    mkdir -p /home/${USER_NAME}/.config/xfce4/xfconf/xfce-perchannel-xml; \
    mkdir -p /home/${USER_NAME}/.cache/sessions; \
    mkdir -p /home/${USER_NAME}/.local/share/xfce4; \
    chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.config; \
    chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.cache; \
    chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.local; \
    # XDG 디렉토리 생성
    mkdir -p /etc/xdg; \
    chmod 755 /etc/xdg

EXPOSE 3389
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]