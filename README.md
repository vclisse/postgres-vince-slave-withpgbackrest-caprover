# PostgreSQL Slave avec pgBackRest sur CapRover

## Variables d'environnement requises

Configurez ces variables dans l'onglet "App Configs" de CapRover:

**Variables essentielles:**
- `BACKREST_PRIMARY_HOST`: Nom d'hôte/IP du serveur principal pgBackRest
- `BACKREST_PRIMARY_USER`: Utilisateur SSH sur le serveur principal (défaut: postgres)
- `BACKREST_STANZA`: Nom du stanza pgBackRest (défaut: psql)

**Variables optionnelles pour la réplication:**
- `PG_PRIMARY_HOST`: Hôte PostgreSQL primaire (défaut: postgres_master)
- `PG_PRIMARY_PORT`: Port PostgreSQL primaire (défaut: 5432)
- `PG_REPLICATION_USER`: Utilisateur pour la réplication (défaut: replicator)
- `PG_REPLICATION_PASSWORD`: Mot de passe pour la réplication (défaut: replication)
- `PG_SLAVE_NAME`: Nom de l'application slave (défaut: slave)

## Configuration du déploiement

1. Connectez-vous au panneau d'administration CapRover
2. Créez une nouvelle application (par exemple `postgres-slave`)
3. Allez dans l'onglet "Deployment" de votre application
4. Choisissez la méthode Deploy from Github/Bitbucket/Gitlab ou uploadez les fichiers directement

## Configuration des volumes persistants

1. Dans le panneau CapRover, allez dans l'onglet "App Configs"
2. Dans la section "Persistent Directories", ajoutez:
   - `/var/lib/postgresql/data`
   - `/var/lib/pgbackrest`
   - `/var/lib/postgresql/.ssh`
3. Cliquez sur "Save & Update"

## Configuration SSH pour pgBackRest

### 1. Créez une paire de clés SSH

```bash
# Sur votre machine locale
ssh-keygen -t rsa -b 4096 -f id_rsa_pgbackrest -C "pgbackrest-slave"
```

### 2. Copiez les clés vers le volume SSH dans CapRover

Connectez-vous au serveur CapRover et localisez le volume SSH:

```bash
# Sur le serveur CapRover
sudo ls -la /captain/data/volumes/
# Localisez l'ID du volume SSH
sudo cp id_rsa* /captain/data/volumes/[ID_VOLUME_SSH]/
sudo chmod 600 /captain/data/volumes/[ID_VOLUME_SSH]/id_rsa
sudo chown -R 999:999 /captain/data/volumes/[ID_VOLUME_SSH]/
```

### 3. Ajoutez la clé publique au serveur principal

Sur votre serveur PostgreSQL principal:

```bash
# Ajoutez la clé publique au fichier authorized_keys
cat id_rsa_pgbackrest.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## Vérification et dépannage

### Vérifier les logs

```bash
# Dans l'interface CapRover: App > Logs
# Ou via SSH sur le serveur CapRover:
docker logs [container_id]
```

### Tester manuellement pgBackRest

Si vous avez besoin de tester la connexion et la configuration pgBackRest:

```bash
# Connectez-vous au conteneur
docker exec -it [container_id] bash

# Test de la connexion SSH (en tant qu'utilisateur postgres)
su - postgres -c "ssh -i ~/.ssh/id_rsa postgres@[BACKREST_PRIMARY_HOST]"

# Test de la commande pgBackRest info
su - postgres -c "pgbackrest --stanza=psql info"

# Test de restauration
su - postgres -c "pgbackrest --stanza=psql --log-level-console=detail restore"
```

### Problèmes courants et solutions

1. **Erreur "does this stanza exist?"**
   - Vérifiez que le stanza existe sur le serveur principal
   - Assurez-vous que la connexion SSH fonctionne correctement
   - Vérifiez que les chemins dans la configuration pgBackRest sont corrects

2. **Problèmes de connexion SSH**
   - Vérifiez les clés SSH et leurs permissions (600 pour id_rsa)
   - Assurez-vous que le serveur principal accepte les connexions SSH
   - Testez manuellement la connexion SSH depuis le conteneur

3. **Erreur de restauration**
   - Vérifiez qu'un backup existe sur le serveur principal
   - Assurez-vous que les chemins dans la configuration pgBackRest sont accessibles
   - Vérifiez les permissions des répertoires

## Vérification du fonctionnement

Après la configuration, vous pouvez vérifier le fonctionnement de votre instance en:

1. Vérifiant les logs dans l'interface CapRover
2. Vous connectant à la base de données via le port exposé
3. Exécutant `pg_isready` pour vérifier que PostgreSQL répond correctement

```
psql -h <adresse-ip-ou-nom-domaine> -p <port-mappé> -U postgres
```

## Dépannage

Si le slave ne démarre pas correctement:
- Vérifiez que les backups pgBackRest sont accessibles dans le volume
- Vérifiez que les clés SSH sont correctement configurées avec les bonnes permissions
- Examinez les logs de PostgreSQL pour identifier les erreurs spécifiques
