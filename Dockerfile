FROM mcr.microsoft.com/playwright:v1.51.1-noble

ENV HOME_EX=/app

RUN rm -f /etc/apt/sources.list.d/* && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble main multiverse restricted universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble-updates main multiverse restricted universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://security.ubuntu.com/ubuntu noble-security main multiverse restricted universe" >> /etc/apt/sources.list

RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    nano \
    bash \
    jq \
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L -o /tmp/s5cmd.tar.gz \
    https://github.com/peak/s5cmd/releases/download/v2.3.0/s5cmd_2.3.0_Linux-64bit.tar.gz && \
    tar -xzf /tmp/s5cmd.tar.gz -C /tmp && \
    mv /tmp/s5cmd /usr/local/bin/ && \
    chmod +x /usr/local/bin/s5cmd && \
    rm -rf /tmp/s5cmd*

RUN groupadd -g 1007 runner && \
    useradd -u 1007 -g runner -m -d "$HOME_EX" runner && \
    mkdir -p "$HOME_EX" && \
    chown -R runner:runner "$HOME_EX"

WORKDIR $HOME_EX

RUN npm set strict-ssl=false && \
    npm init -y && \
    npm ci

RUN chown -R runner:runner $HOME_EX

COPY --chown=runner:runner scripts/ /scripts/
COPY --chown=runner:runner scripts/runtimes/playwright-setup.sh /scripts/runtime-setup.sh
COPY --chown=runner:runner --chmod=755 entrypoint.sh /app/entrypoint.sh

RUN chmod -R 755 /scripts

USER 1007

ENTRYPOINT ["/app/entrypoint.sh"]
