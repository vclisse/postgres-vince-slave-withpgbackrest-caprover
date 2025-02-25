#!/bin/bash
set -e

# Configuration de pgBackRest pour la récupération
setup_pgbackrest() {
    # Vérification de l'existence du répertoire pgBackRest
    if [ ! -d "$BACKREST_REPO1_PATH" ]; then
        mkdir -p $BACKREST_REPO1_PATH
        chown postgres:postgres $BACKREST_REPO1_PATH
    fi
    
    # Configurer pgBackRest si le fichier de configuration n'existe pas
    if [ ! -f "/etc/pgbackrest.conf" ]; then
        cat > /etc/pgbackrest.conf << EOF
[global]
repo1-path=$BACKREST_REPO1_PATH
repo1-retention-full=1

[${BACKREST_STANZA}]
pg1-path=${PGDATA}
EOF
        chown postgres:postgres /etc/pgbackrest.conf
    fi
}

# Initialisation du slave à partir du backup pgBackRest
initialize_slave() {
    if [ ! -f "${PGDATA}/PG_VERSION" ]; then
        echo "Initializing slave from pgBackRest backup..."
        
        # S'assurer que le répertoire PGDATA est vide et appartient à l'utilisateur postgres
        rm -rf ${PGDATA}/*
        chown -R postgres:postgres ${PGDATA}
        
        # Exécuter la restauration en tant que postgres
        su postgres -c "pgbackrest --stanza=${BACKREST_STANZA} restore"
        
        # Configurer pour le mode de réplication
        if [ ! -f "${PGDATA}/recovery.conf" ] && [ ! -f "${PGDATA}/recovery.signal" ]; then
            # Pour PostgreSQL 12+
            touch ${PGDATA}/standby.signal
            cat > ${PGDATA}/postgresql.auto.conf << EOF
primary_conninfo = 'host=postgres_master port=5432 user=replicator password=replication application_name=slave'
recovery_target_timeline = 'latest'
EOF
        fi
        
        chown -R postgres:postgres ${PGDATA}
    fi
}

# Exécuter la configuration
setup_pgbackrest
initialize_slave

# Exécuter la commande originale Docker
exec "$@"
