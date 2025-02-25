# PostgreSQL Slave avec pgBackRest sur CapRover

## Configuration du déploiement

1. Connectez-vous au panneau d'administration CapRover
2. Créez une nouvelle application (par exemple `postgres-slave`)
3. Allez dans l'onglet "Deployment" de votre application
4. Choisissez la méthode Deploy from Github/Bitbucket/Gitlab ou uploadez les fichiers directement

## Configuration des volumes après déploiement

Après le déploiement initial, vous devez configurer les volumes persistants et y ajouter vos configurations:

1. Dans le panneau d'administration CapRover, allez dans l'onglet "App Configs"
2. Dans la section "Persistent Directories", ajoutez:
   - `/var/lib/postgresql/data`
   - `/var/lib/pgbackrest`
   - `/var/lib/postgresql/.ssh`
3. Cliquez sur "Save & Update"

### Configuration SSH et pgBackRest

Pour ajouter vos fichiers de configuration:

1. Connectez-vous au serveur CapRover via SSH
2. Localisez les volumes persistants dans `/captain/data/volumes/`
3. Ajoutez vos fichiers de configuration pgBackRest:
   ```bash
   sudo cp /chemin/vers/vos/fichiers/* /captain/data/volumes/[ID_VOLUME_PGBACKREST]/
   ```
4. Ajoutez vos clés SSH:
   ```bash
   sudo cp /chemin/vers/vos/clés/* /captain/data/volumes/[ID_VOLUME_SSH]/
   sudo chmod 600 /captain/data/volumes/[ID_VOLUME_SSH]/id_rsa
   ```

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
