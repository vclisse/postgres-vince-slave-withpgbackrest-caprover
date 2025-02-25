FROM postgres:${PG_VERSION:-15}

# Variables d'environnement
ENV PG_VERSION=${PG_VERSION:-15} \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    PGDATA=/var/lib/postgresql/data \
    BACKREST_STANZA=psql \
    BACKREST_REPO1_PATH=/var/lib/pgbackrest \
    SSH_PUBLIC_KEY='' \
    SSH_PORT=22

# Installation des dépendances
RUN apt-get update && apt-get install -y \
    pgbackrest \
    openssh-client \
    openssh-server \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*



# Création des répertoires et configuration des permissions
RUN mkdir -p /var/lib/pgbackrest \
    && mkdir -p /var/lib/postgresql/.ssh \
    && chown -R postgres:postgres /var/lib/pgbackrest /var/lib/postgresql/.ssh \
    && chmod 700 /var/lib/postgresql/.ssh


# Configuration de l'entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Volumes et ports
VOLUME ["/var/lib/postgresql/data", "/var/lib/pgbackrest", "/var/lib/postgresql/.ssh"]
EXPOSE 5432

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["postgres"]
