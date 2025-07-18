# 🔒 Собственный безопасный образ FreeSWITCH
# Основан на официальном Debian (проверенная безопасность)
FROM debian:12-slim

# Метаданные образа
LABEL maintainer="Dailer Team"
LABEL description="Secure FreeSWITCH for Dailer Project"
LABEL version="1.10.12"

# Обновляем пакеты и устанавливаем зависимости
RUN apt-get update && apt-get install -y \
    # Основные утилиты
    curl \
    wget \
    gnupg2 \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    # Сетевые утилиты для диагностики
    netcat-openbsd \
    telnet \
    net-tools \
    iputils-ping \
    # Очистка кэша
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Добавляем официальный репозиторий FreeSWITCH
RUN curl -fSsL https://files.freeswitch.org/repo/deb/debian-release/fsstretch-archive-keyring.asc | \
    gpg --dearmor --output /usr/share/keyrings/freeswitch-archive-keyring.gpg

RUN echo "deb [signed-by=/usr/share/keyrings/freeswitch-archive-keyring.gpg] \
    https://files.freeswitch.org/repo/deb/debian-release/ bookworm main" > \
    /etc/apt/sources.list.d/freeswitch.list

# Устанавливаем FreeSWITCH из официального репозитория
RUN apt-get update && apt-get install -y \
    freeswitch \
    freeswitch-meta-all \
    freeswitch-mod-commands \
    freeswitch-mod-console \
    freeswitch-mod-logfile \
    freeswitch-mod-event-socket \
    freeswitch-mod-sofia \
    freeswitch-mod-dptools \
    freeswitch-mod-dialplan-xml \
    freeswitch-mod-spandsp \
    freeswitch-mod-g722 \
    freeswitch-mod-g729 \
    freeswitch-mod-amr \
    freeswitch-mod-ilbc \
    freeswitch-mod-speex \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Создаем пользователя freeswitch для безопасности
RUN useradd -r -s /bin/false freeswitch

# Создаем необходимые директории
RUN mkdir -p /var/lib/freeswitch \
             /var/log/freeswitch \
             /var/run/freeswitch \
             /etc/freeswitch

# Устанавливаем права доступа
RUN chown -R freeswitch:freeswitch /var/lib/freeswitch \
                                   /var/log/freeswitch \
                                   /var/run/freeswitch \
                                   /etc/freeswitch

# Копируем базовую конфигурацию FreeSWITCH
RUN cp -r /usr/share/freeswitch/conf/vanilla/* /etc/freeswitch/

# Создаем минимальную конфигурацию Event Socket
RUN echo '<?xml version="1.0" encoding="UTF-8"?>' > /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '<configuration name="event_socket.conf" description="Socket Client">' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '  <settings>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '    <param name="nat-map" value="false"/>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '    <param name="listen-ip" value="0.0.0.0"/>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '    <param name="listen-port" value="8021"/>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '    <param name="password" value="ClueCon"/>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '    <param name="apply-inbound-acl" value="loopback.auto"/>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '    <param name="stop-on-bind-error" value="true"/>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '  </settings>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '</configuration>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml

# Настраиваем права на конфигурацию
RUN chown -R freeswitch:freeswitch /etc/freeswitch

# Expose стандартные порты FreeSWITCH
EXPOSE 5060/udp 5080/udp 8021/tcp 16384-16394/udp

# Создаем entrypoint скрипт
RUN echo '#!/bin/bash' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Ждем готовности сети' >> /docker-entrypoint.sh && \
    echo 'sleep 5' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Запускаем FreeSWITCH в foreground режиме' >> /docker-entrypoint.sh && \
    echo 'exec /usr/bin/freeswitch -nc -nf -u freeswitch -g freeswitch' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Настраиваем healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD fs_cli -x "status" || exit 1

# Точка входа
ENTRYPOINT ["/docker-entrypoint.sh"] 