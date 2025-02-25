FROM alpine:3.18

ARG PG_VERSION=15

# Installation des dépendances système
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
    postgresql-libs \
    gcc \
    musl-dev \
    python3-dev \
    libffi-dev \
    && mkdir -p /run/postgresql \
    && chown postgres:postgres /run/postgresql

# Configuration de l'environnement PostgreSQL
ENV PGDATA=/var/lib/postgresql/data \
    PATH=/usr/lib/postgresql/${PG_VERSION}/bin:$PATH \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    BACKREST_STANZA=psql \
    BACKREST_REPO1_PATH=/var/lib/pgbackrest \
    SSH_PORT=22

# Installation des packages Python
COPY requirements.txt /app/
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Configuration des répertoires
RUN mkdir -p /var/lib/postgresql/data \
    /var/lib/pgbackrest \
    /var/lib/postgresql/.ssh \
    /app/web \
    && chown -R postgres:postgres \
        /var/lib/postgresql \
        /var/lib/pgbackrest \
    && chmod 700 /var/lib/postgresql/.ssh

# Copie des fichiers de l'application
COPY ./web /app/web
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Configuration de Streamlit
ENV STREAMLIT_SERVER_PORT=8501 \
    STREAMLIT_SERVER_ADDRESS=0.0.0.0

# Volumes et ports
VOLUME ["/var/lib/postgresql/data", "/var/lib/pgbackrest", "/var/lib/postgresql/.ssh"]
EXPOSE 5432 8501

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["postgres"]
