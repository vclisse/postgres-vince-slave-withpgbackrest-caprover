FROM ubuntu:22.04

# Variables d'environnement
ENV PG_VERSION=15 \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    PGDATA=/var/lib/postgresql/data \
    BACKREST_STANZA=psql \
    BACKREST_REPO1_PATH=/var/lib/pgbackrest \
    SSH_PUBLIC_KEY='' \
    SSH_PORT=22 \
    DEBIAN_FRONTEND=noninteractive

# Installation des dépendances et PostgreSQL
RUN apt-get update && \
    apt-get install -y gnupg2 wget lsb-release && \
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y \
    postgresql-${PG_VERSION} \
    postgresql-client-${PG_VERSION} \
    pgbackrest \
    openssh-client \
    openssh-server \
    gosu \
    && rm -rf /var/lib/apt/lists/*

# Configuration de PostgreSQL
RUN mkdir -p ${PGDATA} && \
    chown postgres:postgres ${PGDATA} && \
    chmod 700 ${PGDATA} && \
    mkdir -p /var/run/postgresql && \
    chown postgres:postgres /var/run/postgresql && \
    chmod 775 /var/run/postgresql

# Configuration des répertoires pour pgBackRest et SSH
RUN mkdir -p /var/lib/pgbackrest \
    && mkdir -p /var/lib/postgresql/.ssh \
    && mkdir -p /var/log/pgbackrest \
    && mkdir -p /var/run/sshd \
    && chown -R postgres:postgres /var/lib/pgbackrest /var/lib/postgresql/.ssh /var/log/pgbackrest \
    && chmod 700 /var/lib/postgresql/.ssh

# Copie des scripts
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Volumes et ports
VOLUME ["${PGDATA}", "/var/lib/pgbackrest", "/var/lib/postgresql/.ssh"]
EXPOSE 5432 ${SSH_PORT}

USER postgres
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["postgres", "-D", "/var/lib/postgresql/data"]
