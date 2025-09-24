FROM ubuntu:latest

# Variables (in Kubeflow, the default volume mount path is set to home/jovyan, so we pick the same username)
ENV NB_USER=jovyan
ENV NB_UID=1001
ENV NB_GID=0
ENV NB_PREFIX=/
ENV HOME=/home/$NB_USER
ENV SHELL=/bin/bash
ENV USERS_GID=100
ENV HOME_TMP=/tmp_home/$NB_USER

# Other kubeflow related variables
# ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME=300000
# ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2
# ENV LANG=en_US.UTF-8
# ENV LANGUAGE=en_US.UTF-8
# ENV LC_ALL=en_US.UTF-8

# Build arguments
ARG TARGETARCH
ARG KUBECTL_VERSION=v1.31.6
ARG S6_VERSION=v3.2.0.2
ARG CODESERVER_VERSION=4.96.4

# Allow root access in container
USER root

# Set the default shell to bash
SHELL ["/bin/bash", "-c"]

# Install standard Linux packages
RUN export DEBIAN_FRONTEND=noninteractive \
 && apt-get -yq update \
 && apt-get -yq install --no-install-recommends \
    apt-transport-https \
    bash \
    dos2unix \
    bzip2 \
    ca-certificates \
    curl \
    git \
    gnupg \
    gnupg2 \
    locales \
    lsb-release \
    nano \
    software-properties-common \
    tzdata \
    unzip \
    vim \
    wget \
    xz-utils \
    zip \
    sudo \
 && \
 apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Install s6-overlay (process supervisor)
RUN case "${TARGETARCH}" in \
      amd64) S6_ARCH="x86_64" ;; \
      arm64) S6_ARCH="aarch64" ;; \
      ppc64le) S6_ARCH="ppc64le" ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac \
 && curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-noarch.tar.xz" -o /tmp/s6-overlay-noarch.tar.xz \
 && curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-noarch.tar.xz.sha256" -o /tmp/s6-overlay-noarch.tar.xz.sha256 \
 && echo "$(cat /tmp/s6-overlay-noarch.tar.xz.sha256 | awk '{ print $1; }')  /tmp/s6-overlay-noarch.tar.xz" | sha256sum -c - \
 && curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" -o /tmp/s6-overlay-${S6_ARCH}.tar.xz \
 && curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-${S6_ARCH}.tar.xz.sha256" -o /tmp/s6-overlay-${S6_ARCH}.tar.xz.sha256 \
 && echo "$(cat /tmp/s6-overlay-${S6_ARCH}.tar.xz.sha256 | awk '{ print $1; }')  /tmp/s6-overlay-${S6_ARCH}.tar.xz" | sha256sum -c - \
 && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
 && tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz \
 && rm /tmp/s6-overlay-noarch.tar.xz  \
       /tmp/s6-overlay-noarch.tar.xz.sha256 \
       /tmp/s6-overlay-${S6_ARCH}.tar.xz \
       /tmp/s6-overlay-${S6_ARCH}.tar.xz.sha256

# Permissions for s6
RUN chmod 0775 /run

# Install kubectl
RUN curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
 && curl -fsSL "https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256" -o /tmp/kubectl.sha256 \
 && echo "$(cat /tmp/kubectl.sha256 | awk '{ print $1; }')  /usr/local/bin/kubectl" | sha256sum -c - \
 && rm /tmp/kubectl.sha256 \
 && chmod +x /usr/local/bin/kubectl

# Create user
RUN useradd -M -N \
    --shell /bin/bash \
    --home ${HOME} \
    --uid ${NB_UID} \
    --gid ${NB_GID} \
    --groups ${USERS_GID} \
    ${NB_USER} \
 && mkdir -pv ${HOME} \
 && mkdir -pv ${HOME_TMP} \
 && chmod 2775 ${HOME} \
 && chmod 2775 ${HOME_TMP} \
 && chown -R ${NB_USER}:${USERS_GID} ${HOME} \
 && chown -R ${NB_USER}:${USERS_GID} ${HOME_TMP} \
 && chown -R ${NB_USER}:${NB_GID} /usr/local/bin

# Set locale
RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
 && locale-gen

# Copy s6 service scripts to /etc
COPY --chown=${NB_USER}:${NB_GID} --chmod=755 s6/ /etc

# Fix line endings and permissions for s6 scripts
RUN find /etc/cont-init.d /etc/services.d -type f -print0 | xargs -0 -r dos2unix \
 && chmod -R +x /etc/cont-init.d /etc/services.d


# ===============================================================================================


# Install VSCode server
RUN curl -fsSL "https://github.com/coder/code-server/releases/download/v${CODESERVER_VERSION}/code-server_${CODESERVER_VERSION}_${TARGETARCH}.deb" -o /tmp/code-server.deb \
 && dpkg -i /tmp/code-server.deb || true \
 && apt-get -yq update \
 && apt-get -yq -f install --no-install-recommends \
 && rm -f /tmp/code-server.deb \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
EXPOSE 8888

# ===============================================================================================

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# ===============================================================================================

# Start Ollama server (default port 11434)
RUN ollama serve

# ===============================================================================================

# Pull llama3.1 model
RUN ollama pull llama3.1

# ===============================================================================================

# Install Python & dev tools
RUN apt-get update && apt-get -yq install --no-install-recommends python3 python3.12-dev build-essential g++ cmake ninja-build python3-venv && alias python=python3
RUN python3 -m venv ${HOME}/.venv

# ===============================================================================================

# Start
ENTRYPOINT ["/init"]
