/*
Architecture & Rôles :

Objectif : Créer un serveur slave PostgreSQL sans port ouvert, basé sur l'image officielle PostgreSQL 15.

Fonctionnalités :
- Le container doit lancer PostgreSQL en mode slave.
- En mode recovery, le fichier de configuration (postgresql.conf ou le dossier PGDATA) doit être configuré avec une commande de restauration des WAL, par exemple :
  restore_command = 'pgbackrest --stanza=psql archive-get %f %p'
- Générer automatiquement les clés SSH au démarrage afin de permettre une connexion SSH sortante.
- Installer pgBackRest et les outils SSH dans l'image.
- pgBackRest doit pouvoir être utilisé via des variables d’environnement pour restaurer la sauvegarde initiale et récupérer les WAL archivés.

Documentation :
- Documenter les actions à réaliser sur le serveur principal dans un fichier README.md, mais ne se concentrer que sur le développement du serveur slave.

Contraintes :
- Le serveur principal ne doit établir que des connexions sortantes.
*/
