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
echo "Configuration du serveur SSH..."

# Générer les clés SSH du serveur si elles n'existent pas
ssh-keygen -A

# Configurer sshd
sed -i "s/#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo "AllowUsers postgres" >> /etc/ssh/sshd_config

# Configurer le répertoire .ssh pour postgres
mkdir -p /var/lib/postgresql/.ssh
touch /var/lib/postgresql/.ssh/authorized_keys

# Ajouter la clé SSH si fournie
if [ ! -z "${SSH_PUBLIC_KEY}" ]; then
    echo "${SSH_PUBLIC_KEY}" > /var/lib/postgresql/.ssh/authorized_keys
fi

# Configurer les permissions correctes
chown -R postgres:postgres /var/lib/postgresql/.ssh
chmod 700 /var/lib/postgresql/.ssh
chmod 600 /var/lib/postgresql/.ssh/authorized_keys

# Démarrer SSH
/usr/sbin/sshd

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

# Exécuter la configuration de pgBackRest
setup_pgbackrest

# Configurer le recovery pour PostgreSQL
setup_recovery_conf

echo "Démarrage de PostgreSQL en mode slave..."
# Basculer vers l'utilisateur postgres pour le reste des opérations
exec gosu postgres "$@"
