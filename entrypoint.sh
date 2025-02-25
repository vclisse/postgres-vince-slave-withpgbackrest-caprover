#!/bin/bash
set -e

# Configuration de pgBackRest pour la récupération
setup_pgbackrest() {
    echo "Configuration de pgBackRest..."
    
    # Vérification des répertoires nécessaires
    mkdir -p $BACKREST_REPO1_PATH
    chown postgres:postgres $BACKREST_REPO1_PATH
    
    # Configuration SSH
    if [ -d "/var/lib/postgresql/.ssh" ]; then
        echo "Configuration SSH..."
        chmod 700 /var/lib/postgresql/.ssh
        chmod 600 /var/lib/postgresql/.ssh/*
        chown -R postgres:postgres /var/lib/postgresql/.ssh
        
        # Démarrer le service SSH si nécessaire
        service ssh start || echo "SSH service non disponible"
    else
        echo "ATTENTION: Répertoire SSH non trouvé!"
    fi
    
    # Créer une configuration pgBackRest qui pointe vers le serveur principal
    cat > /etc/pgbackrest.conf << EOF
[global]
repo1-path=$BACKREST_REPO1_PATH
repo1-type=posix
repo1-host=${BACKREST_PRIMARY_HOST:-localhost}
repo1-host-user=${BACKREST_PRIMARY_USER:-postgres}

[${BACKREST_STANZA}]
pg1-path=${PGDATA}
EOF
    
    chown postgres:postgres /etc/pgbackrest.conf
    echo "Configuration pgBackRest terminée"
    
    # Afficher la configuration pour débogage
    echo "Contenu du fichier de configuration pgBackRest:"
    cat /etc/pgbackrest.conf
    
    # Afficher les informations sur le stanza
    echo "Informations sur le stanza (pourrait échouer si le stanza n'existe pas encore):"
    su postgres -c "pgbackrest --stanza=${BACKREST_STANZA} info || echo 'Stanza non trouvé, sera créé durant la restauration'"
}

# Initialisation du slave à partir du backup pgBackRest
initialize_slave() {
    if [ ! -f "${PGDATA}/PG_VERSION" ]; then
        echo "Initializing slave from pgBackRest backup..."
        
        # S'assurer que le répertoire PGDATA est vide et appartient à l'utilisateur postgres
        rm -rf ${PGDATA}/*
        chown -R postgres:postgres ${PGDATA}
        
        # Vérifier si nous pouvons accéder au serveur de sauvegarde
        if [ ! -z "${BACKREST_PRIMARY_HOST}" ]; then
            echo "Tentative de connexion SSH au serveur principal ${BACKREST_PRIMARY_HOST}..."
            su postgres -c "ssh -o StrictHostKeyChecking=no -i /var/lib/postgresql/.ssh/id_rsa ${BACKREST_PRIMARY_USER:-postgres}@${BACKREST_PRIMARY_HOST} 'echo SSH OK'"
        fi
        
        # Exécuter la restauration en tant que postgres
        echo "Tentative de restauration pgBackRest..."
        su postgres -c "pgbackrest --stanza=${BACKREST_STANZA} --log-level-console=detail restore || (echo 'ERREUR: Restauration échouée' && exit 1)"
        
        # Configurer pour le mode de réplication
        echo "Configuration du mode de réplication..."
        # Pour PostgreSQL 12+
        touch ${PGDATA}/standby.signal
        cat > ${PGDATA}/postgresql.auto.conf << EOF
primary_conninfo = 'host=${PG_PRIMARY_HOST:-postgres_master} port=${PG_PRIMARY_PORT:-5432} user=${PG_REPLICATION_USER:-replicator} password=${PG_REPLICATION_PASSWORD:-replication} application_name=${PG_SLAVE_NAME:-slave}'
recovery_target_timeline = 'latest'
EOF
        
        chown -R postgres:postgres ${PGDATA}
        echo "Initialisation terminée avec succès."
    else
        echo "Instance PostgreSQL déjà initialisée."
    fi
}

echo "Démarrage du script entrypoint PostgreSQL Slave..."
# Exécuter la configuration
setup_pgbackrest

# Initialiser le slave uniquement si les variables nécessaires sont définies
if [ ! -z "${BACKREST_PRIMARY_HOST}" ]; then
    initialize_slave
else
    echo "AVERTISSEMENT: BACKREST_PRIMARY_HOST non défini, l'initialisation du slave est reportée."
    echo "Définissez cette variable pour une initialisation automatique."
fi

echo "Démarrage de PostgreSQL..."
# Exécuter la commande originale Docker
exec "$@"
