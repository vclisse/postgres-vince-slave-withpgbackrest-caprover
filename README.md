# PostgreSQL Slave avec pgBackRest

Ce conteneur Docker configure un serveur PostgreSQL en mode slave/standby qui utilise pgBackRest pour recevoir les sauvegardes et WAL archivés envoyés depuis le serveur principal. Le slave est conçu pour fonctionner sans port ouvert vers l'extérieur.

## Architecture de sécurité

Cette solution utilise une architecture sécurisée où:
- Le serveur principal initie toutes les connexions vers le serveur slave (push model)
- Le serveur slave n'a aucun port entrant exposé à l'exception du SSH pour recevoir les données
- Les sauvegardes et WAL sont envoyés par le serveur principal via SSH

## Fonctionnalités

- Configuration automatique pour recevoir les sauvegardes pgBackRest
- Configuration automatique du mode slave avec restauration des WAL
- Génération automatique des clés SSH (la clé publique doit être installée sur le serveur slave)
- Zéro connexion sortante depuis le slave (toutes les connexions sont initiées par le principal)

## Variables d'environnement

### Obligatoires
- `SSH_PORT`: Port SSH sur lequel le serveur slave écoute (défaut: 22)
- `BACKREST_STANZA`: Nom du stanza pgBackRest (défaut: psql)

### Optionnelles
- `SSH_PUBLIC_KEY`: Clé publique SSH du serveur principal à ajouter aux authorized_keys
- `PG_SLAVE_NAME`: Nom de l'application slave (défaut: slave)

## Configuration du slave avec CapRover

1. Créez une nouvelle application dans CapRover
2. Configurez les volumes persistants:
   - `/var/lib/postgresql/data`
   - `/var/lib/pgbackrest`
   - `/var/lib/postgresql/.ssh`
3. Définissez les variables d'environnement requises
4. Déployez l'application

## Configuration côté serveur principal PostgreSQL

### 1. Installation des paquets requis

```bash
sudo apt-get update
sudo apt-get install -y postgresql-15 postgresql-15-pgbackrest openssh-client
```

### 2. Configuration de pgBackRest sur le serveur principal

Ajoutez cette configuration à `/etc/pgbackrest.conf`:

```ini
[global]
repo1-path=/var/lib/pgbackrest
repo1-retention-full=2
process-max=4
log-path=/var/log/pgbackrest
repo1-type=posix

# Configuration pour envoyer les données au serveur slave via SSH
repo1-host=<ADRESSE_IP_DU_SLAVE>
repo1-host-user=postgres
repo1-host-port=22

[psql]
pg1-path=/var/lib/postgresql/15/main
pg1-port=5432
```

### 3. Configurer le serveur PostgreSQL principal

Ajoutez ces lignes à `/etc/postgresql/15/main/postgresql.conf`:

```
archive_mode = on
archive_command = 'pgbackrest --stanza=psql archive-push %p'
max_wal_senders = 10
wal_level = replica
```

### 4. Configuration SSH pour pgBackRest sur le serveur principal

Générez une paire de clés SSH pour l'utilisateur postgres sur le serveur principal:

```bash
sudo -u postgres ssh-keygen -t rsa -b 4096 -f ~postgres/.ssh/id_rsa -N ''
```

Récupérez la clé publique générée:

```bash
cat /var/lib/postgresql/.ssh/id_rsa.pub
```

Utilisez cette clé comme valeur pour la variable d'environnement `SSH_PUBLIC_KEY` lors du déploiement du slave.

### 5. Initialisation du stanza pgBackRest

```bash
sudo -u postgres pgbackrest --stanza=psql stanza-create
sudo -u postgres pgbackrest --stanza=psql check
sudo -u postgres pgbackrest --stanza=psql backup
```

## Vérification et dépannage

### Vérifier les logs du slave

```
docker logs [container_id]
```

### Les problèmes courants

1. **Erreur de connexion SSH depuis le serveur principal**
   - Vérifiez que la clé publique du serveur principal est correctement ajoutée à authorized_keys du slave
   - Vérifiez que le service SSH fonctionne sur le slave
   
2. **Erreur lors de l'envoi des WAL**
   - Vérifiez que l'archive_command fonctionne correctement sur le serveur principal
   - Assurez-vous que `/var/lib/pgbackrest` sur le slave a les permissions correctes
