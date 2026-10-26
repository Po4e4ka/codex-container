FROM ubuntu:24.04

# ===== ENV =====
ENV APP_USER=codex \
    APP_UID=1000 \
    APP_GID=1000 \
    DEBIAN_FRONTEND=noninteractive

ARG NODE_MAJOR=22
ARG PHP_VERSION=8.4

# ===== BASE PACKAGES =====
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    wget \
    nano \
    vim \
    build-essential \
    jq \
    ripgrep \
    fd-find \
    tree \
    htop \
    tmux \
    screen \
    zip \
    unzip \
    tar \
    gzip \
    whois \
    bzip2 \
    xz-utils \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    sqlite3 \
    libsqlite3-dev \
    postgresql-client \
    libpq-dev \
    redis-tools \
    ca-certificates \
    openssh-client \
    software-properties-common \
    apt-transport-https \
    gnupg \
    lsb-release \
    sed \
    gawk \
    grep \
    iputils-ping \
    imagemagick \
    ffmpeg \
    libxml2-dev \
    libxslt1-dev \
    libyaml-dev \
    libffi-dev \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    iproute2 \
    libcurl4-openssl-dev \
    nftables \
    util-linux \
    iptables \
    && rm -rf /var/lib/apt/lists/*

# ===== SING-BOX =====
RUN curl -fsSL https://sing-box.app/install.sh -o /tmp/install-sing-box.sh \
    && chmod +x /tmp/install-sing-box.sh \
    && /tmp/install-sing-box.sh \
    && rm -f /tmp/install-sing-box.sh \
    && sing-box version


# ===== XRAY =====
# The proxy is a BuildKit secret and is never stored in an image layer.
RUN --mount=type=secret,id=xray_proxy \
    export ALL_PROXY="$(cat /run/secrets/xray_proxy 2>/dev/null || true)" \
    && curl --http1.1 --retry 5 --retry-all-errors --retry-delay 3 -fsSL \
        https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh \
        -o /tmp/install-xray.sh \
    && mkdir -p /tmp/xray-curl \
    && printf '%s\n' '#!/bin/sh' 'exec /usr/bin/curl --http1.1 --retry-all-errors "$@"' \
        > /tmp/xray-curl/curl \
    && chmod +x /tmp/xray-curl/curl \
    && (set -- install; if [ -n "$ALL_PROXY" ]; then set -- "$@" --proxy "$ALL_PROXY"; fi; \
        attempt=1; until PATH="/tmp/xray-curl:$PATH" \
            bash /tmp/install-xray.sh "$@"; do \
        if [ "$attempt" -ge 3 ]; then exit 1; fi; \
        echo "Retrying Xray installation ($attempt/3)..."; \
        attempt=$((attempt + 1)); sleep 3; \
    done) \
    && rm -rf /tmp/install-xray.sh /tmp/xray-curl \
    && xray version


# ===== LANGUAGE REPOSITORIES =====
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        -o /tmp/nodesource.gpg.key \
    && gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg /tmp/nodesource.gpg.key \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && add-apt-repository -y ppa:ondrej/php \
    && rm -f /tmp/nodesource.gpg.key

# ===== DOCKER REPOSITORY =====
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && . /etc/os-release \
    && printf '%s\n' \
        'Types: deb' \
        'URIs: https://download.docker.com/linux/ubuntu' \
        "Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}" \
        'Components: stable' \
        "Architectures: $(dpkg --print-architecture)" \
        'Signed-By: /etc/apt/keyrings/docker.asc' \
        > /etc/apt/sources.list.d/docker.sources

# ===== NODE / PHP =====
RUN apt-get update && apt-get install -y \
    nodejs \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-zip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://composer.github.io/installer.sig -o /tmp/composer.sig \
    && curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php \
    && php -r "if (trim(file_get_contents('/tmp/composer.sig')) !== hash_file('sha384', '/tmp/composer-setup.php')) { fwrite(STDERR, 'Invalid Composer installer signature' . PHP_EOL); exit(1); }" \
    && php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm -f /tmp/composer.sig /tmp/composer-setup.php

# ===== DOCKER CLI =====
RUN apt-get update && apt-get install -y \
    docker-ce-cli \
    docker-buildx-plugin \
    docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# ===== PYTHON PACKAGES =====
RUN apt-get update && apt-get install -y \
    python3-pillow \
    python3-requests \
    python3-numpy \
    python3-pandas \
    python3-pydantic \
    python3-lxml \
    python3-imageio \
    && rm -rf /var/lib/apt/lists/*

# ===== VPN CONFIG =====
RUN usermod -l $APP_USER ubuntu
RUN groupmod -n $APP_USER ubuntu
RUN usermod -d /home/$APP_USER -m $APP_USER
RUN groupadd -f docker && usermod -aG docker $APP_USER

# ===== WORKDIR =====
WORKDIR /home/$APP_USER

# ===== INSTALL CODEX =====
ARG CACHE_BUST=0
RUN echo "CACHE_BUST=${CACHE_BUST}" >/dev/null && npm install -g @openai/codex@latest

USER 0:0

COPY entrypoint.sh /entrypoint.sh
COPY CONTEXT.md /home/$APP_USER/CONTEXT.md

RUN chmod +x /entrypoint.sh \
    && mkdir -p /etc/xray /etc/sing-box

ENTRYPOINT ["/entrypoint.sh"]
