#!/bin/bash
set -e

# Génération des clés SSH si elles n'existent pas
generate_ssh_keys() {
    echo "Vérification des clés SSH..."
    if [ ! -f "/var/lib/postgresql/.ssh/id_rsa" ]; then
        echo "Génération automatique des clés SSH..."
        mkdir -p /var/lib/postgresql/.ssh
        # Générer une clé sans passphrase pour l'automatisation
        su - postgres -c "ssh-keygen -t rsa -b 4096 -f /var/lib/postgresql/.ssh/id_rsa -N ''"
        echo "Clés SSH générées avec succès."
        echo "Clé publique générée:"
        cat /var/lib/postgresql/.ssh/id_rsa.pub
        echo "IMPORTANT: Cette clé publique doit être ajoutée au fichier authorized_keys sur le serveur principal."
    else
        echo "Clés SSH existantes trouvées."
    fi
    
    # Configurer les permissions SSH
    chmod 700 /var/lib/postgresql/.ssh
    chmod 600 /var/lib/postgresql/.ssh/id_rsa
    chown -R postgres:postgres /var/lib/postgresql/.ssh
}

# Configuration de pgBackRest pour la récupération
setup_pgbackrest() {
    echo "Configuration de pgBackRest..."
    
    # Vérification des répertoires nécessaires
    mkdir -p $BACKREST_REPO1_PATH
    chown postgres:postgres $BACKREST_REPO1_PATH
    
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
    
    # Tester la connexion SSH vers le serveur principal si configuré
    if [ ! -z "${BACKREST_PRIMARY_HOST}" ]; then
        echo "Test de la connexion SSH vers ${BACKREST_PRIMARY_HOST}..."
        su postgres -c "ssh -o StrictHostKeyChecking=no -i /var/lib/postgresql/.ssh/id_rsa ${BACKREST_PRIMARY_USER:-postgres}@${BACKREST_PRIMARY_HOST} 'echo SSH OK'" || echo "ATTENTION: La connexion SSH a échoué. Vérifiez que la clé publique est correctement installée sur le serveur principal."
    fi
}

# Initialisation du slave à partir du backup pgBackRest
initialize_slave() {
    if [ ! -f "${PGDATA}/PG_VERSION" ]; then
        echo "Initialisation du slave depuis le backup pgBackRest..."
        
        # S'assurer que le répertoire PGDATA est vide et appartient à l'utilisateur postgres
        rm -rf ${PGDATA}/*
        chown -R postgres:postgres ${PGDATA}
        
        # Exécuter la restauration en tant que postgres
        echo "Tentative de restauration pgBackRest..."
        su postgres -c "pgbackrest --stanza=${BACKREST_STANZA} --log-level-console=detail restore"
        
        if [ $? -ne 0 ]; then
            echo "ERREUR: La restauration pgBackRest a échoué!"
            echo "Vérifiez que le stanza existe sur le serveur principal et que la connexion SSH fonctionne."
            exit 1
        fi
        
        # Configurer pour le mode de réplication
        echo "Configuration du mode slave..."
        
        # Pour PostgreSQL 12+, créer le fichier standby.signal
        touch ${PGDATA}/standby.signal
        
        # Configurer la récupération des WAL et la connexion au serveur principal
        cat > ${PGDATA}/postgresql.auto.conf << EOF
primary_conninfo = 'host=${PG_PRIMARY_HOST:-postgres_master} port=${PG_PRIMARY_PORT:-5432} user=${PG_REPLICATION_USER:-replicator} password=${PG_REPLICATION_PASSWORD:-replication} application_name=${PG_SLAVE_NAME:-slave}'
recovery_target_timeline = 'latest'
restore_command = 'pgbackrest --stanza=${BACKREST_STANZA} archive-get %f %p'
EOF
        
        # Configurer les paramètres de performance du slave si nécessaires
        cat >> ${PGDATA}/postgresql.auto.conf << EOF
# Configuration recommandée pour le mode slave
hot_standby = on
max_standby_archive_delay = 30s
max_standby_streaming_delay = 30s
EOF
        
        chown -R postgres:postgres ${PGDATA}
        echo "Configuration du slave terminée avec succès."
    else
        echo "Instance PostgreSQL déjà initialisée."
    fi
}

echo "Démarrage du script entrypoint PostgreSQL Slave..."

# Générer les clés SSH
generate_ssh_keys

# Exécuter la configuration de pgBackRest
setup_pgbackrest

# Initialiser le slave uniquement si les variables nécessaires sont définies
if [ ! -z "${BACKREST_PRIMARY_HOST}" ]; then
    initialize_slave
else
    echo "AVERTISSEMENT: BACKREST_PRIMARY_HOST non défini, l'initialisation du slave est reportée."
    echo "Définissez cette variable pour une initialisation automatique."
fi

echo "Démarrage de PostgreSQL en mode slave..."
# Exécuter la commande originale Docker
exec "$@"
