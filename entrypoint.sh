#!/bin/bash
set -e

# Vérification des volumes persistants
check_persistent_volumes() {
    echo "Vérification des volumes persistants..."
    
    # Vérifier le volume PGDATA
    if [ ! -d "/var/lib/postgresql/data" ]; then
        echo "ERREUR: Le volume persistant pour PGDATA n'est pas monté!"
        exit 1
    fi
    
    # Vérifier le volume pgbackrest
    if [ ! -d "/var/lib/pgbackrest" ]; then
        echo "ERREUR: Le volume persistant pour pgbackrest n'est pas monté!"
        exit 1
    fi
    
    # Vérifier le volume SSH
    if [ ! -d "/var/lib/postgresql/.ssh" ]; then
        echo "ERREUR: Le volume persistant pour SSH n'est pas monté!"
        exit 1
    fi
    
    # Créer le sous-répertoire pgdata si nécessaire
    if [ ! -d "$PGDATA" ]; then
        mkdir -p "$PGDATA"
        chown postgres:postgres "$PGDATA"
        chmod 700 "$PGDATA"
    fi
    
    # Créer le répertoire WAL si nécessaire
    if [ ! -d "$POSTGRES_INITDB_WALDIR" ]; then
        mkdir -p "$POSTGRES_INITDB_WALDIR"
        chown postgres:postgres "$POSTGRES_INITDB_WALDIR"
        chmod 700 "$POSTGRES_INITDB_WALDIR"
    fi
    
    echo "Vérification des volumes terminée avec succès."
}

# Configuration du serveur SSH
setup_ssh_server() {
    echo "Configuration du serveur SSH..."
    
    # S'assurer que le répertoire .ssh existe
    mkdir -p /var/lib/postgresql/.ssh
    touch /var/lib/postgresql/.ssh/authorized_keys
    
    # Si une clé publique est fournie via les variables d'environnement, l'ajouter
    if [ ! -z "${SSH_PUBLIC_KEY}" ]; then
        echo "Ajout de la clé publique SSH fournie..."
        echo "${SSH_PUBLIC_KEY}" >> /var/lib/postgresql/.ssh/authorized_keys
        echo "Clé publique ajoutée avec succès."
    else
        echo "AVERTISSEMENT: Aucune clé SSH_PUBLIC_KEY fournie. Le serveur principal ne pourra pas se connecter sans clé."
    fi
    
    # Configurer les permissions SSH
    chmod 700 /var/lib/postgresql/.ssh
    chmod 600 /var/lib/postgresql/.ssh/authorized_keys
    chown -R postgres:postgres /var/lib/postgresql/.ssh
    
    # Configuration du serveur SSH
    sed -i 's/#Port 22/Port ${SSH_PORT:-22}/g' /etc/ssh/sshd_config
    
    # Démarrer le serveur SSH
    service ssh start
    
    echo "Serveur SSH configuré et démarré sur le port ${SSH_PORT:-22}."
}

# Configuration de pgBackRest pour le slave
setup_pgbackrest() {
    echo "Configuration de pgBackRest pour le serveur slave..."
    
    # Vérification des répertoires nécessaires
    mkdir -p ${BACKREST_REPO1_PATH:-/var/lib/pgbackrest}
    chown postgres:postgres ${BACKREST_REPO1_PATH:-/var/lib/pgbackrest}
    
    # Créer une configuration pgBackRest pour le slave
    cat > /etc/pgbackrest.conf << EOF
[global]
repo1-path=${BACKREST_REPO1_PATH:-/var/lib/pgbackrest}
repo1-type=posix

[${BACKREST_STANZA:-psql}]
pg1-path=${PGDATA}
EOF
    
    chown postgres:postgres /etc/pgbackrest.conf
    echo "Configuration pgBackRest terminée"
    
    # Afficher la configuration pour débogage
    echo "Contenu du fichier de configuration pgBackRest:"
    cat /etc/pgbackrest.conf
}

# Configuration du fichier de recovery PostgreSQL
setup_recovery_conf() {
    if [ ! -f "${PGDATA}/PG_VERSION" ]; then
        echo "Initialisation du serveur PostgreSQL en mode standby..."
        
        # Utiliser directement la commande initdb qui est dans le PATH
        su - postgres -c "initdb -D ${PGDATA}"
        
        # Pour PostgreSQL 12+, créer le fichier standby.signal
        touch ${PGDATA}/standby.signal
        
        # Configurer la récupération des WAL depuis le repository
        cat > ${PGDATA}/postgresql.auto.conf << EOF
# Configuration du slave
restore_command = 'pgbackrest --stanza=${BACKREST_STANZA:-psql} archive-get %f %p'
recovery_target_timeline = 'latest'
hot_standby = on
EOF
        
        chown -R postgres:postgres ${PGDATA}
        echo "Configuration du slave terminée."
    else
        echo "Instance PostgreSQL déjà initialisée."
    fi
}

# Démarrer Streamlit en arrière-plan
start_web_interface() {
    echo "Démarrage de l'interface web Streamlit..."
    streamlit run /app/web/app.py &
}

echo "Démarrage du script entrypoint PostgreSQL Slave..."

# Vérifier les volumes avant toute autre opération
check_persistent_volumes

# Configurer le serveur SSH
setup_ssh_server

# Exécuter la configuration de pgBackRest
setup_pgbackrest

# Configurer le recovery pour PostgreSQL
setup_recovery_conf

# Démarrer l'interface web Streamlit
start_web_interface

echo "Démarrage de PostgreSQL en mode slave..."
# Exécuter la commande originale Docker
exec "$@"
