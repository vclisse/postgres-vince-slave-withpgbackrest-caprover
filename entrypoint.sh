#!/bin/bash
set -e

# Correction du PATH pour PostgreSQL
export PATH="/usr/lib/postgresql/${PG_VERSION}/bin:$PATH"

# Fonction pour trouver initdb
find_initdb() {
    for possible_path in \
        "/usr/lib/postgresql/${PG_VERSION}/bin/initdb" \
        "/usr/local/bin/initdb" \
        "/usr/bin/initdb"
    do
        if [ -x "$possible_path" ]; then
            echo "$possible_path"
            return 0
        fi
    done
    return 1
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
        
        # Trouver initdb
        INITDB_PATH=$(find_initdb)
        if [ -z "$INITDB_PATH" ]; then
            echo "ERREUR: impossible de trouver initdb"
            exit 1
        fi
        
        echo "Utilisation de initdb: $INITDB_PATH"
        su postgres -c "$INITDB_PATH -D ${PGDATA}"
        
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

echo "Démarrage du script entrypoint PostgreSQL Slave..."

# Configuration SSH (exécutée en tant que root)
if [ ! -f "/etc/ssh/ssh_host_rsa_key" ]; then
    ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
    ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N '' -t ecdsa
    ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N '' -t ed25519
fi

# Modifier la configuration SSH si nécessaire
sed -i "s/#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config

# Démarrer le service SSH
/usr/sbin/sshd

# Configuration de la clé SSH publique si fournie
if [ ! -z "${SSH_PUBLIC_KEY}" ]; then
    echo "${SSH_PUBLIC_KEY}" > /var/lib/postgresql/.ssh/authorized_keys
    chmod 600 /var/lib/postgresql/.ssh/authorized_keys
    chown postgres:postgres /var/lib/postgresql/.ssh/authorized_keys
fi

# Configurer le serveur SSH
setup_ssh_server

# Exécuter la configuration de pgBackRest
setup_pgbackrest

# Configurer le recovery pour PostgreSQL
setup_recovery_conf

echo "Démarrage de PostgreSQL en mode slave..."
# Basculer vers l'utilisateur postgres pour le reste des opérations
exec gosu postgres "$@"
