# Rebuild s5cmd with patched Go (Xray: github.com/golang/go 1.22.10 -> 1.26.6).
FROM golang:1.26.6-bookworm AS s5cmd
RUN git clone --depth 1 --branch v2.3.0 https://github.com/peak/s5cmd.git /src
WORKDIR /src
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o /s5cmd .

FROM mcr.microsoft.com/playwright:v1.62.1-noble

ENV HOME_EX=/app
ENV HOME=/app
ENV BRU_BIN="/app/node_modules/@usebruno/cli/bin"

RUN rm -f /etc/apt/sources.list.d/* && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble main multiverse restricted universe" > /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble-updates main multiverse restricted universe" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb [arch=amd64] http://security.ubuntu.com/ubuntu noble-security main multiverse restricted universe" >> /etc/apt/sources.list

RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    git \
    nano \
    bash \
    file \
    jq \
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

COPY --from=s5cmd /s5cmd /usr/local/bin/s5cmd
RUN chmod +x /usr/local/bin/s5cmd

# Playwright image ships yarn 1.22.22 (CVE-2025-9308, no newer 1.x). Runner does not use it.
RUN npm uninstall -g yarn >/dev/null 2>&1 || true; \
    rm -rf /usr/lib/node_modules/yarn /usr/bin/yarn /usr/bin/yarnpkg

RUN groupadd -g 1007 runner && \
    useradd -u 1007 -g runner -m -d "$HOME_EX" runner && \
    mkdir -p "$HOME_EX" && \
    chown -R runner:runner "$HOME_EX"

WORKDIR $HOME_EX

COPY package.json package-lock.json .npmrc ./
RUN npm install -g npm@11.19.0 --no-fund --no-audit
RUN npm set strict-ssl=false && \
    npm init -y && \
    npm ci

RUN chown -R runner:runner $HOME_EX

COPY --chown=runner:runner --chmod=755 scripts/ /scripts/
COPY --chown=runner:runner scripts/runtimes/playwright-setup.sh /scripts/runtime-setup.sh
COPY --chown=runner:runner --chmod=755 entrypoint.sh /app/entrypoint.sh
COPY --chown=runner:runner --chmod=755 detect-missed-tests.sh /app/detect-missed-tests.sh
COPY --chown=runner:runner --chmod=755 capture-test-list.sh /app/capture-test-list.sh

RUN chgrp -R 0 /app /scripts \
    && chmod -R g=u /app /scripts \
    && chmod g+rx /app /scripts

USER 1007

ENTRYPOINT ["/app/entrypoint.sh"]