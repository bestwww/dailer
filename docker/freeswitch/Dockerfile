# 🔒 Собственный безопасный образ FreeSWITCH
# Основан на официальном Debian (проверенная безопасность)
FROM debian:12-slim

# Метаданные образа
LABEL maintainer="Dailer Team"
LABEL description="Secure FreeSWITCH for Dailer Project"
LABEL version="1.10.12"

# Устанавливаем зависимости для компиляции FreeSWITCH
RUN apt-get update && apt-get install -y \
    # Базовые инструменты сборки
    build-essential \
    cmake \
    automake \
    autoconf \
    libtool \
    pkg-config \
    git \
    # Зависимости FreeSWITCH
    libssl-dev \
    libcurl4-openssl-dev \
    libpcre3-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libedit-dev \
    libtiff5-dev \
    yasm \
    # Аудио и видео кодеки
    libavformat-dev \
    libswscale-dev \
    # База данных
    libsqlite3-dev \
    # Сетевые утилиты для диагностики
    netcat-openbsd \
    telnet \
    net-tools \
    iputils-ping \
    # Очистка кэша
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Компилируем FreeSWITCH из исходных кодов (МАКСИМАЛЬНАЯ БЕЗОПАСНОСТЬ!)
RUN cd /usr/src && \
    git clone https://github.com/signalwire/freeswitch.git -b v1.10.12 && \
    cd freeswitch && \
    # Настраиваем сборку
    ./bootstrap.sh -j && \
    ./configure \
        --prefix=/usr/local/freeswitch \
        --sysconfdir=/etc/freeswitch \
        --enable-core-libedit-support \
        --disable-dependency-tracking \
        --enable-zrtp && \
    # Компилируем (занимает время, но результат стоит того!)
    make -j$(nproc) && \
    make install && \
    # Очищаем исходники для экономии места
    cd / && rm -rf /usr/src/freeswitch

# Создаем пользователя freeswitch для безопасности
RUN useradd -r -s /bin/false freeswitch

# Создаем необходимые директории для собранного FreeSWITCH
RUN mkdir -p /usr/local/freeswitch/log \
             /usr/local/freeswitch/db \
             /usr/local/freeswitch/storage \
             /usr/local/freeswitch/recordings \
             /usr/local/freeswitch/run

# Устанавливаем права доступа
RUN chown -R freeswitch:freeswitch /usr/local/freeswitch \
                                   /etc/freeswitch

# Создаем правильную конфигурацию Event Socket
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

# Создаем базовый modules.conf.xml для загрузки необходимых модулей
RUN echo '<?xml version="1.0" encoding="UTF-8"?>' > /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '<configuration name="modules.conf" description="Modules">' >> /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '  <modules>' >> /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '    <load module="mod_event_socket"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '    <load module="mod_sofia"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '    <load module="mod_commands"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '    <load module="mod_console"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '    <load module="mod_dptools"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '    <load module="mod_dialplan_xml"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '  </modules>' >> /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '</configuration>' >> /etc/freeswitch/autoload_configs/modules.conf.xml

# Настраиваем права на конфигурацию
RUN chown -R freeswitch:freeswitch /etc/freeswitch

# Добавляем FreeSWITCH в PATH
ENV PATH="/usr/local/freeswitch/bin:${PATH}"

# Expose стандартные порты FreeSWITCH
EXPOSE 5060/udp 5080/udp 8021/tcp 16384-16394/udp

# Создаем entrypoint скрипт
RUN echo '#!/bin/bash' > /docker-entrypoint.sh && \
    echo 'set -e' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Ждем готовности сети' >> /docker-entrypoint.sh && \
    echo 'sleep 5' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Проверяем права доступа' >> /docker-entrypoint.sh && \
    echo 'chown -R freeswitch:freeswitch /usr/local/freeswitch /etc/freeswitch' >> /docker-entrypoint.sh && \
    echo '' >> /docker-entrypoint.sh && \
    echo '# Запускаем FreeSWITCH в foreground режиме' >> /docker-entrypoint.sh && \
    echo 'exec /usr/local/freeswitch/bin/freeswitch \' >> /docker-entrypoint.sh && \
    echo '    -conf /etc/freeswitch \' >> /docker-entrypoint.sh && \
    echo '    -log /usr/local/freeswitch/log \' >> /docker-entrypoint.sh && \
    echo '    -db /usr/local/freeswitch/db \' >> /docker-entrypoint.sh && \
    echo '    -storage /usr/local/freeswitch/storage \' >> /docker-entrypoint.sh && \
    echo '    -recordings /usr/local/freeswitch/recordings \' >> /docker-entrypoint.sh && \
    echo '    -run /usr/local/freeswitch/run \' >> /docker-entrypoint.sh && \
    echo '    -u freeswitch -g freeswitch \' >> /docker-entrypoint.sh && \
    echo '    -nf -nc' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Настраиваем healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD /usr/local/freeswitch/bin/fs_cli -x "status" || exit 1

# Точка входа
ENTRYPOINT ["/docker-entrypoint.sh"] 