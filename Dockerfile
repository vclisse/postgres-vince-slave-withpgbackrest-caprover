FROM alpine:3.18

# Version de PostgreSQL
ARG PG_VERSION=15

# Installation des dépendances système et Python
RUN apk add --no-cache \
    postgresql${PG_VERSION} \
    postgresql${PG_VERSION}-contrib \
    postgresql${PG_VERSION}-dev \
    pgbackrest \
    openssh \
    python3 \
    py3-pip \
    py3-wheel \
    py3-setuptools \
    py3-numpy \
    py3-pandas \
    py3-psycopg2 \
    py3-cryptography \
    py3-yaml \
    py3-click \
    py3-protobuf \
    gcc \
    musl-dev \
    python3-dev \
    libffi-dev \
    openssl-dev \
    linux-headers \
    postgresql-libs \
    && mkdir -p /run/postgresql \
    && chown postgres:postgres /run/postgresql

# Installation de pip dans un répertoire utilisateur
ENV PATH=/root/.local/bin:$PATH
RUN python3 -m pip install --user --no-cache-dir --upgrade pip setuptools wheel

# Installation des packages Python
RUN python3 -m pip install --user --no-cache-dir \
    streamlit \
    "psycopg[binary]" \
    watchdog

# Configuration de l'environnement PostgreSQL
ENV PGDATA=/var/lib/postgresql/data \
    PATH=/usr/lib/postgresql/${PG_VERSION}/bin:$PATH \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    BACKREST_STANZA=psql \
    BACKREST_REPO1_PATH=/var/lib/pgbackrest \
    SSH_PORT=22 \
    SSH_PUBLIC_KEY=''

# Création des répertoires nécessaires
RUN mkdir -p /var/lib/postgresql/data \
    /var/lib/pgbackrest \
    /var/lib/postgresql/.ssh \
    && chown -R postgres:postgres \
        /var/lib/postgresql \
        /var/lib/pgbackrest \
    && chmod 700 /var/lib/postgresql/.ssh

# Copie des fichiers
COPY ./web /app/web
COPY ./entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Configuration de Streamlit
ENV STREAMLIT_SERVER_PORT=8501 \
    STREAMLIT_SERVER_ADDRESS=0.0.0.0

# Volumes et ports
VOLUME ["/var/lib/postgresql/data", "/var/lib/pgbackrest", "/var/lib/postgresql/.ssh"]
EXPOSE 5432 8501

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["postgres"]
