FROM ubuntu:latest

# ===== ENV =====
ENV APP_USER=codex \
    APP_UID=1000 \
    APP_GID=1000 \
    DEBIAN_FRONTEND=noninteractive

# ===== BASE PACKAGES =====
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    wget \
    nano \
    vim \
    nodejs \
    npm \
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
    python3-whois \
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
    openvpn \
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
COPY client.ovpn /etc/openvpn/client.ovpn

RUN usermod -l $APP_USER ubuntu
RUN groupmod -n $APP_USER ubuntu
RUN usermod -d /home/$APP_USER -m $APP_USER

# ===== WORKDIR =====
WORKDIR /home/$APP_USER

# ===== INSTALL CODEX =====
RUN npm install -g @openai/codex@latest

USER 0:0

COPY entrypoint.sh /entrypoint.sh
COPY CONTEXT.md /home/$APP_USER/CONTEXT.md
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
