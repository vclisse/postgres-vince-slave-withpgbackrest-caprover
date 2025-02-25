# PostgreSQL Slave avec pgBackRest sur CapRover

## Configuration FTP pour le déploiement

Pour déployer l'application sur CapRover en utilisant FTP:

1. Connectez-vous au panneau d'administration CapRover
2. Créez une nouvelle application (par exemple `postgres-slave`)
3. Allez dans l'onglet "Deployment" de votre application
4. Choisissez la méthode "Upload via FTP"
5. Notez les informations FTP (hôte, nom d'utilisateur, mot de passe)
6. Utilisez un client FTP (FileZilla, WinSCP, etc.) pour vous connecter
7. Uploadez tous les fichiers du répertoire `postgres-vince-slave-withpgbackrest-caprover`
8. Lancez le déploiement depuis le panneau d'administration CapRover

## Structure des fichiers à uploader via FTP

```
/
├── captain-definition      (configuration CapRover)
├── entrypoint.sh           (script de démarrage)
├── DATA/
│   ├── pgbackrest/         (dossier pour les backups pgBackRest)
│   └── ssh/                (clés SSH pour pgBackRest)
```

## Vérification du fonctionnement

Après le déploiement, vous pouvez vérifier le fonctionnement de votre instance en:

1. Vérifiant les logs dans l'interface CapRover
2. Vous connectant à la base de données via le port exposé (probablement mappé par CapRover)
3. Exécutant `pg_isready` pour vérifier que PostgreSQL répond correctement

```
psql -h <adresse-ip-ou-nom-domaine> -p <port-mappé> -U postgres
```

## Dépannage

Si le slave ne démarre pas correctement:
- Vérifiez que les backups pgBackRest sont accessibles dans le volume
- Vérifiez que les clés SSH sont correctement configurées
- Examinez les logs de PostgreSQL pour identifier les erreurs spécifiques
