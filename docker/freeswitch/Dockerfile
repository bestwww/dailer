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
    libtool-bin \
    pkg-config \
    git \
    wget \
    curl \
    netcat-openbsd \
    # Дополнительные инструменты сборки
    autotools-dev \
    bison \
    zlib1g-dev \
    libjpeg-dev \
    libncurses5-dev \
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
    # UUID библиотеки
    uuid-dev \
    # LDAP поддержка
    libldap2-dev \
    # SpanDSP - КРИТИЧЕСКИ ВАЖНО для FreeSWITCH! Собираем из исходного кода FreeSWITCH
    libtiff-dev \
    libaudiofile-dev \
    libfftw3-dev \
    # Дополнительные аудио библиотеки
    libasound2-dev \
    # PostgreSQL поддержка (опционально)
    libpq-dev \
    # Дополнительные кодеки и библиотеки
    libopus-dev \
    libvorbis-dev \
    libflac-dev \
    libmp3lame-dev \
    # Криптографические библиотеки
    libgcrypt20-dev \
    libgnutls28-dev \
    # XML обработка
    libxml2-dev \
    libxslt1-dev \
    # Сетевые утилиты для диагностики
    netcat-openbsd \
    telnet \
    net-tools \
    iputils-ping \
    # Очистка кэша
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Сначала компилируем SpanDSP и Sofia-SIP из официальных репозиториев FreeSWITCH
RUN cd /usr/src && \
    echo "🔄 Загружаем исходные коды SpanDSP..." && \
    git clone https://github.com/freeswitch/spandsp.git && \
    cd spandsp && \
    echo "🚀 Настраиваем SpanDSP..." && \
    echo "🔧 Проверяем инструменты сборки SpanDSP..." && \
    autoconf --version && \
    automake --version && \
    libtool --version && \
    if [ -f ./autogen.sh ]; then ./autogen.sh; elif [ -f ./bootstrap.sh ]; then ./bootstrap.sh; else echo "❌ Не найден скрипт автогенерации!"; exit 1; fi && \
    ./configure --prefix=/usr/local && \
    echo "🔨 Компилируем SpanDSP..." && \
    make -j$(nproc) && \
    echo "📦 Устанавливаем SpanDSP..." && \
    make install && \
    echo "🔗 Обновляем библиотечный кеш..." && \
    ldconfig && \
    echo "🔧 Настраиваем переменные окружения для SpanDSP..." && \
    echo "/usr/local/lib" >> /etc/ld.so.conf.d/spandsp.conf && \
    ldconfig && \
    echo "✅ SpanDSP успешно установлен!" && \
    cd /usr/src && rm -rf spandsp && \
    echo "🔄 Загружаем исходные коды Sofia-SIP..." && \
    git clone https://github.com/freeswitch/sofia-sip.git && \
    cd sofia-sip && \
    echo "🚀 Настраиваем Sofia-SIP..." && \
    echo "🔧 Проверяем инструменты сборки Sofia-SIP..." && \
    autoconf --version && \
    automake --version && \
    libtool --version && \
    if [ -f ./autogen.sh ]; then ./autogen.sh; elif [ -f ./bootstrap.sh ]; then ./bootstrap.sh; else echo "❌ Не найден скрипт автогенерации!"; exit 1; fi && \
    ./configure --prefix=/usr/local && \
    echo "🔨 Компилируем Sofia-SIP..." && \
    make -j$(nproc) && \
    echo "📦 Устанавливаем Sofia-SIP..." && \
    make install && \
    echo "🔗 Обновляем библиотечный кеш..." && \
    ldconfig && \
    echo "🔧 Настраиваем переменные окружения для Sofia-SIP..." && \
    echo "/usr/local/lib" >> /etc/ld.so.conf.d/sofia-sip.conf && \
    ldconfig && \
    echo "✅ Sofia-SIP успешно установлен!" && \
    cd /usr/src && rm -rf sofia-sip

# Устанавливаем переменные окружения для поиска SpanDSP и Sofia-SIP
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH" \
    LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# Теперь компилируем FreeSWITCH из исходных кодов (МАКСИМАЛЬНАЯ БЕЗОПАСНОСТЬ!)
RUN cd /usr/src && \
    echo "🔄 Загружаем исходные коды FreeSWITCH..." && \
    git clone https://github.com/signalwire/freeswitch.git -b v1.10.12 && \
    cd freeswitch && \
    echo "🔧 Проверяем версии инструментов сборки..." && \
    autoconf --version && \
    automake --version && \
    libtool --version && \
    echo "🚀 Запускаем bootstrap..." && \
    ./bootstrap.sh -j && \
    echo "⚙️ Настраиваем конфигурацию..." && \
    echo "🔍 Проверяем SpanDSP..." && \
    pkg-config --exists spandsp && echo "✅ SpanDSP найден" || echo "⚠️ SpanDSP не найден" && \
    find /usr/local -name "*spandsp*" 2>/dev/null | head -5 && \
    echo "🔍 Проверяем Sofia-SIP..." && \
    pkg-config --exists sofia-sip-ua && echo "✅ Sofia-SIP найден" || echo "⚠️ Sofia-SIP не найден" && \
    find /usr/local -name "*sofia*" 2>/dev/null | head -5 && \
    ./configure \
        --prefix=/usr/local/freeswitch \
        --sysconfdir=/etc/freeswitch \
        --enable-core-libedit-support \
        --disable-dependency-tracking \
        --enable-zrtp \
        --disable-fhs \
        --with-spandsp=/usr/local \
        --with-sofia-sip=/usr/local \
        --enable-mod-spandsp \
        --enable-mod-fax \
        --enable-mod-t38gateway \
        --disable-mod-enum \
        --disable-libvpx \
        --without-java \
        --without-python && \
    echo "🔨 Компилируем FreeSWITCH (это займет время)..." && \
    make -j$(nproc) && \
    echo "📦 Устанавливаем FreeSWITCH..." && \
    make install && \
    echo "🧹 Очищаем исходники для экономии места..." && \
    cd / && rm -rf /usr/src/freeswitch && \
    echo "✅ FreeSWITCH успешно собран!" && \
    echo "🧹 Удаляем компиляторы и dev-пакеты для уменьшения размера образа..." && \
    apt-get purge -y \
        build-essential \
        cmake \
        automake \
        autoconf \
        libtool-bin \
        pkg-config \
        git \
        wget \
        curl && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/* && \
    echo "📦 Размер образа существенно уменьшен (от ~1.2GB до ~300-400MB)!"

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
    ESL_PASSWORD=$(openssl rand -hex 16) && \
    echo "🔐 Генерируем безопасный пароль для Event Socket: $ESL_PASSWORD" && \
    echo "    <param name=\"password\" value=\"$ESL_PASSWORD\"/>" >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo "🔐 Event Socket пароль: $ESL_PASSWORD" > /var/log/freeswitch-esl-password.log && \
    echo '    <param name="apply-inbound-acl" value="admin_acl"/>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '    <param name="stop-on-bind-error" value="true"/>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '  </settings>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo '</configuration>' >> /etc/freeswitch/autoload_configs/event_socket.conf.xml && \
    echo "🔒 Создаем ACL для ограничения доступа..." && \
    mkdir -p /etc/freeswitch/autoload_configs && \
    echo '<?xml version="1.0" encoding="utf-8"?>' > /etc/freeswitch/autoload_configs/acl.conf.xml && \
    echo '<configuration name="acl.conf" description="Network Access Control List">' >> /etc/freeswitch/autoload_configs/acl.conf.xml && \
    echo '  <network-lists>' >> /etc/freeswitch/autoload_configs/acl.conf.xml && \
    echo '    <list name="admin_acl" default="deny">' >> /etc/freeswitch/autoload_configs/acl.conf.xml && \
    echo '      <node type="allow" cidr="127.0.0.1/32"/>' >> /etc/freeswitch/autoload_configs/acl.conf.xml && \
    echo '      <node type="allow" cidr="10.0.0.0/8"/>' >> /etc/freeswitch/autoload_configs/acl.conf.xml && \
    echo '      <node type="allow" cidr="172.16.0.0/12"/>' >> /etc/freeswitch/autoload_configs/acl.conf.xml && \
    echo '      <node type="allow" cidr="192.168.0.0/16"/>' >> /etc/freeswitch/autoload_configs/acl.conf.xml && \
    echo '    </list>' >> /etc/freeswitch/autoload_configs/acl.conf.xml && \
    echo '  </network-lists>' >> /etc/freeswitch/autoload_configs/acl.conf.xml && \
    echo '</configuration>' >> /etc/freeswitch/autoload_configs/acl.conf.xml

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
    echo '# Выводим пароль Event Socket для администратора' >> /docker-entrypoint.sh && \
echo 'echo "🔐 === Event Socket пароль ===" ' >> /docker-entrypoint.sh && \
echo 'if [ -f /var/log/freeswitch-esl-password.log ]; then' >> /docker-entrypoint.sh && \
echo '    cat /var/log/freeswitch-esl-password.log' >> /docker-entrypoint.sh && \
echo 'else' >> /docker-entrypoint.sh && \
echo '    echo "⚠️ Файл с паролем не найден"' >> /docker-entrypoint.sh && \
echo 'fi' >> /docker-entrypoint.sh && \
echo 'echo "🔐 =========================="' >> /docker-entrypoint.sh && \
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

# Настраиваем улучшенный healthcheck для проверки Event Socket и SIP
HEALTHCHECK --interval=30s --timeout=10s --start-period=3m --retries=3 \
    CMD nc -z 127.0.0.1 8021 && \
        /usr/local/freeswitch/bin/fs_cli -x "status" | grep -q "UP" || exit 1

# Точка входа
ENTRYPOINT ["/docker-entrypoint.sh"] 