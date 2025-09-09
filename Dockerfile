FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
	TZ=Etc/UTC \
	USER_NAME=kbs \
	USER_UID=1000 \
	USER_GID=1000 \
	USER_PASSWORD=asdf0110 \
	LANG=ko_KR.UTF-8 \
	LANGUAGE=ko_KR:ko \
	LC_ALL=ko_KR.UTF-8

# 1) XFCE 세션 및 RDP 관련 패키지
RUN set -eux; \
        apt-get update; \
		apt-get install -y \
			xfce4 xfce4-goodies xrdp xorgxrdp dbus-x11 x11-xserver-utils qemu-user-static

# 2) 한국어/로케일 및 폰트 패키지
RUN set -eux; \
		apt-get install -y\
			locales language-pack-ko fonts-noto-cjk fonts-noto-color-emoji fonts-nanum; \
		locale-gen ko_KR.UTF-8 en_US.UTF-8; \
		update-locale LANG=ko_KR.UTF-8 LANGUAGE=ko_KR:ko LC_ALL=ko_KR.UTF-8;

# 3) 이미지/영상 썸네일 및 미디어 태그/코덱/GVFS 관련 패키지
RUN set -eux; \
		apt-get install -y \
			tumbler ffmpegthumbnailer thunar-media-tags-plugin \
			gstreamer1.0-libav gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
			gvfs gvfs-backends gvfs-fuse

# 4) 오디오  및 VLC
RUN set -eux; \
    apt-get install -y \
        pulseaudio pulseaudio-utils pavucontrol xfce4-pulseaudio-plugin vlc \
        git build-essential autoconf libtool pkg-config dpkg-dev libpulse-dev ca-certificates sudo;

COPY ./startwm.sh /usr/local/bin/startwm.sh
COPY ./start-xrdp.sh /usr/local/bin/start-xrdp.sh

# 사용자/스크립트/권한/링크
RUN set -eux; \
	chmod +x /usr/local/bin/startwm.sh /usr/local/bin/start-xrdp.sh; \
	ln -sf /usr/local/bin/startwm.sh /etc/xrdp/startwm.sh; \
	groupadd -g ${USER_GID} ${USER_NAME}; \
	useradd -m -u ${USER_UID} -g ${USER_GID} -s /bin/bash ${USER_NAME}; \
	echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd; \
	sed -i 's/\r$//' /usr/local/bin/start-xrdp.sh; \
	adduser xrdp ssl-cert; \
	install -d -m 755 /var/run/xrdp; \
	chown xrdp:xrdp /var/run/xrdp

EXPOSE 3389
ENTRYPOINT ["/usr/local/bin/start-xrdp.sh"]