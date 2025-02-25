# PostgreSQL Slave avec pgBackRest

Ce conteneur Docker configure un serveur PostgreSQL en mode slave/standby qui utilise pgBackRest pour la récupération initiale et la restauration des WAL archivés. Le slave est conçu pour fonctionner sans port ouvert vers l'extérieur.

## Fonctionnalités

- Génération automatique des clés SSH au premier démarrage
- Restauration automatique depuis les sauvegardes pgBackRest
- Configuration automatique du mode slave avec la restauration des WAL
- Zéro port entrant requis (seulement des connexions sortantes vers le serveur principal)

## Variables d'environnement

### Obligatoires
- `BACKREST_PRIMARY_HOST`: Nom d'hôte/IP du serveur principal pgBackRest
- `BACKREST_STANZA`: Nom du stanza pgBackRest (défaut: psql)

### Optionnelles
- `BACKREST_PRIMARY_USER`: Utilisateur SSH sur le serveur principal (défaut: postgres)
- `PG_PRIMARY_HOST`: Hôte PostgreSQL primaire (défaut: postgres_master)
- `PG_PRIMARY_PORT`: Port PostgreSQL primaire (défaut: 5432)
- `PG_REPLICATION_USER`: Utilisateur pour la réplication (défaut: replicator)
- `PG_REPLICATION_PASSWORD`: Mot de passe pour la réplication (défaut: replication)
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
sudo apt-get install -y postgresql-15 postgresql-15-pgbackrest openssh-server
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

### 4. Configuration du fichier pg_hba.conf

Ajoutez cette ligne à `/etc/postgresql/15/main/pg_hba.conf`:

```
host replication replicator 0.0.0.0/0 md5
```

### 5. Création d'un utilisateur de réplication

```sql
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replication';
```

### 6. Configuration de SSH pour pgBackRest

Après le premier démarrage du slave, récupérez la clé publique générée dans les logs et ajoutez-la au fichier `authorized_keys` de l'utilisateur postgres sur le serveur principal:

```bash
echo "clé_publique_du_slave" >> /var/lib/postgresql/.ssh/authorized_keys
chmod 600 /var/lib/postgresql/.ssh/authorized_keys
```

### 7. Initialisation du stanza pgBackRest

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

1. **Erreur "clés SSH manquantes"**
   - Les clés sont générées au premier démarrage et doivent être ajoutées sur le serveur principal
   
2. **Erreur "stanza non trouvé"**
   - Vérifiez que le stanza a été créé sur le serveur principal avec `pgbackrest --stanza=psql stanza-create`
   
3. **Erreur de connexion SSH**
   - Vérifiez que la clé publique du slave a été correctement ajoutée au fichier authorized_keys du serveur principal
   - Vérifiez les permissions (`chmod 700 ~/.ssh` et `chmod 600 ~/.ssh/authorized_keys`)
   
4. **Erreur lors de la restauration des WAL**
   - Vérifiez que l'archive_command fonctionne correctement sur le serveur principal
   - Assurez-vous que `/var/lib/pgbackrest` a les permissions correctes
