# FreeSWITCH Dockerfile для системы автодозвона
FROM debian:bullseye-slim

# Метаданные образа
LABEL maintainer="Dialer System"
LABEL description="FreeSWITCH для системы автодозвона с поддержкой ESL и AMD"

# Переменные окружения
ENV FREESWITCH_VERSION=1.10.9
ENV DEBIAN_FRONTEND=noninteractive

# Установка зависимостей и компиляция FreeSWITCH
RUN apt-get update && apt-get install -y \
    # Базовые утилиты
    wget curl gnupg2 software-properties-common \
    # Зависимости для компиляции
    build-essential cmake automake autoconf libtool pkg-config \
    # Аудио и кодеки
    libasound2-dev libspeex-dev libspeexdsp-dev \
    # SSL/TLS поддержка
    libssl-dev \
    # База данных для CDR
    libpq-dev unixodbc-dev \
    # Скриптинг
    liblua5.2-dev \
    # Медиа обработка
    libavformat-dev libswscale-dev \
    # Утилиты
    sox flac git vim \
    && rm -rf /var/lib/apt/lists/*

# Добавляем официальный репозиторий FreeSWITCH
RUN wget -O - https://files.freeswitch.org/repo/deb/debian-release/fsstretch-archive-keyring.asc | apt-key add - && \
    echo "deb http://files.freeswitch.org/repo/deb/debian-release/ bullseye main" > /etc/apt/sources.list.d/freeswitch.list

# Установка FreeSWITCH и модулей
RUN apt-get update && apt-get install -y \
    # Основной пакет FreeSWITCH
    freeswitch \
    # Базовые модули
    freeswitch-mod-commands \
    freeswitch-mod-conference \
    freeswitch-mod-db \
    freeswitch-mod-dptools \
    freeswitch-mod-expr \
    freeswitch-mod-fifo \
    freeswitch-mod-hash \
    freeswitch-mod-voicemail \
    # ESL модуль для интеграции
    freeswitch-mod-event-socket \
    # Аудио модули
    freeswitch-mod-sndfile \
    freeswitch-mod-native-file \
    freeswitch-mod-local-stream \
    freeswitch-mod-tone-stream \
    # SIP модуль
    freeswitch-mod-sofia \
    # Диалплан модули
    freeswitch-mod-dialplan-xml \
    # Логирование
    freeswitch-mod-logfile \
    freeswitch-mod-syslog \
    # AMD модуль (Answering Machine Detection)
    freeswitch-mod-avmd \
    # Дополнительные модули для диалера
    freeswitch-mod-enum \
    freeswitch-mod-cdr-csv \
    freeswitch-mod-httapi \
    && rm -rf /var/lib/apt/lists/*

# Создаем пользователя freeswitch
RUN groupadd -r freeswitch && \
    useradd -r -g freeswitch -d /usr/local/freeswitch -s /bin/bash freeswitch

# Создаем необходимые директории
RUN mkdir -p /usr/local/freeswitch/{log,db,storage,recordings,sounds/custom} && \
    chown -R freeswitch:freeswitch /usr/local/freeswitch

# Копируем базовую конфигурацию
COPY conf/ /usr/local/freeswitch/conf/

# Создаем скрипт запуска
RUN echo '#!/bin/bash\n\
# Проверяем права доступа\n\
chown -R freeswitch:freeswitch /usr/local/freeswitch\n\
\n\
# Запускаем FreeSWITCH в foreground режиме\n\
exec /usr/bin/freeswitch \\\n\
    -u freeswitch \\\n\
    -g freeswitch \\\n\
    -c \\\n\
    -nonat \\\n\
    -nf \\\n\
    -conf /usr/local/freeswitch/conf \\\n\
    -log /usr/local/freeswitch/log \\\n\
    -db /usr/local/freeswitch/db \\\n\
    -storage /usr/local/freeswitch/storage \\\n\
    -recordings /usr/local/freeswitch/recordings \\\n\
    -sounds /usr/local/freeswitch/sounds \\\n\
    -run /usr/local/freeswitch\n' > /usr/local/bin/start-freeswitch.sh && \
    chmod +x /usr/local/bin/start-freeswitch.sh

# Открываем порты
# 5060 - SIP сигналинг
# 8021 - ESL (Event Socket Library)
# 16384-16394 - RTP медиа порты
EXPOSE 5060/udp 5060/tcp 8021 16384-16394/udp

# Переключаемся на пользователя freeswitch
USER freeswitch

# Рабочая директория
WORKDIR /usr/local/freeswitch

# Запускаем FreeSWITCH
CMD ["/usr/local/bin/start-freeswitch.sh"]

# Проверка здоровья контейнера
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD fs_cli -x "status" || exit 1 