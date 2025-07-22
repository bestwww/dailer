# 🆕 Asterisk Docker образ для Dailer
# Альтернатива FreeSWITCH с поддержкой AMI

FROM ubuntu:22.04

# 📋 Метаданные
LABEL maintainer="Dailer Team"
LABEL description="Asterisk for Dailer Project - AMI/ARI support"
LABEL version="20.x"

# 🌍 Переменные окружения
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# 📦 Установка базовых зависимостей
RUN apt-get update && \
    apt-get install -y \
        # Базовые утилиты
        wget \
        curl \
        gnupg2 \
        ca-certificates \
        software-properties-common \
        lsb-release \
        # Сетевые утилиты для диагностики
        netcat-openbsd \
        telnet \
        net-tools \
        iputils-ping \
        dnsutils \
        # Утилиты для работы
        vim \
        nano \
        htop \
        tree \
        # Необходимые библиотеки для Asterisk
        build-essential \
        libxml2-dev \
        libncurses5-dev \
        uuid-dev \
        libjansson-dev \
        libsqlite3-dev \
        libssl-dev \
        # Аудио поддержка
        libasound2-dev \
        libspeex-dev \
        libspeexdsp-dev \
        # Codec поддержка
        libopus-dev \
        libvorbis-dev \
        libmp3lame-dev && \
    echo "✅ Базовые зависимости установлены"

# 🎯 Установка Asterisk из официального репозитория
RUN echo "📦 Установка Asterisk..." && \
    # Добавляем официальный репозиторий Asterisk
    wget -qO- http://deb.asterisk.org/asterisk-public.key | apt-key add - && \
    echo "deb http://deb.asterisk.org/asterisk-20-lts $(lsb_release -sc) main" > /etc/apt/sources.list.d/asterisk.list && \
    apt-get update && \
    # Устанавливаем Asterisk с базовыми модулями
    apt-get install -y \
        asterisk \
        asterisk-modules \
        asterisk-core-sounds-en \
        asterisk-core-sounds-ru && \
    echo "✅ Asterisk установлен"

# 🗂️ Создаем структуру директорий
RUN mkdir -p \
        /etc/asterisk \
        /var/lib/asterisk \
        /var/log/asterisk \
        /var/spool/asterisk \
        /usr/share/asterisk/sounds \
        /tmp/asterisk && \
    echo "✅ Структура директорий создана"

# 👤 Создаем пользователя asterisk
RUN useradd --system --home-dir /var/lib/asterisk --shell /bin/false asterisk && \
    chown -R asterisk:asterisk \
        /etc/asterisk \
        /var/lib/asterisk \
        /var/log/asterisk \
        /var/spool/asterisk \
        /usr/share/asterisk && \
    echo "✅ Пользователь asterisk создан"

# 🔧 Копируем базовую конфигурацию
COPY conf/ /etc/asterisk/
RUN chown -R asterisk:asterisk /etc/asterisk

# 🧹 Очистка для уменьшения размера образа
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/* && \
    echo "🧹 Временные файлы очищены"

# 📂 Рабочая директория
WORKDIR /etc/asterisk

# 🔌 Открываем необходимые порты
# SIP порты
EXPOSE 5060/udp 5060/tcp
# RTP порты
EXPOSE 10000-20000/udp
# AMI (Asterisk Manager Interface)
EXPOSE 5038/tcp
# ARI (Asterisk REST Interface)  
EXPOSE 8088/tcp

# 🏥 Добавляем healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD asterisk -rx "core show version" || exit 1

# 📝 Копируем entrypoint скрипт
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# 🚀 Точка входа
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["asterisk", "-f", "-vvv"] 