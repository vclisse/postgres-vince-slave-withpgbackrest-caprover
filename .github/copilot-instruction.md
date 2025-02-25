# Architecture & Rôles :
- Objectif avoir un serveur slave postgres sans sans port ouvert
– Le container lance PostgreSQL en mode slave.
– Lors du démarrage en mode recovery, pensez à configurer le fichier postgresql.conf du slave (ou le dossier PGDATA) avec une commande de restauration des WAL, par exemple :
restore_command = 'pgbackrest --stanza=psql archive-get %f %p'

– Les clés SSH sont générées automatiquement au démarrage, ce qui permettra d’établir une connexion SSH sortante 
- se base sur l’image officielle PostgreSQL 15 et y installe pgBackRest ainsi que les outils SSH.
- Tu documentes ce qu'il faut faire sur le serveur principal dans README.md mais tu ne t'occupe que du serveur slave
– pgBackRest est installé et pourra être utilisé (via des variables d’environnement) pour restaurer la sauvegarde initiale et récupérer les WAL archivés. 
- Le serveur principal ne peux que des connexion sortante 


# Interfac WEB : 
- dépendance : streamlit psycopg3 

## Interface WEB fonction : 
- Intialiser une DB, Importer un fichier SQL
- Passer du mode slave en mode principal.