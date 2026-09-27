FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    WORK_ROOT=/data/work \
    SCRIPTS_REPO_DIR=/data/repo \
    LOCK_FILE=/data/lock/itnet-useful-mikrotik-scripts.lock \
    GIT_DEPLOY_KEY=/run/secrets/git_deploy_key \
    SCRIPTS_REPO_URL=git@github.com:rtrahimi/itnet-useful-mikrotik-scripts.git \
    SCRIPTS_BRANCH=main \
    COMMIT_NAME="Morteza Rahimi" \
    COMMIT_EMAIL=rtrahimi@gmail.com

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      gawk \
      git \
      openssh-client \
      python3 \
      whois \
      coreutils \
      util-linux \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY bin/ /app/bin/
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh /app/bin/*.sh \
 && mkdir -p /data/work /data/repo /data/lock /run/secrets

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["help"]
