#!/bin/bash
set -e

SSH_DIR="/var/lib/postgresql/.ssh"

# Générer les clés SSH si non présentes
if [ ! -f "${SSH_DIR}/id_rsa" ]; then
  echo "Génération des clés SSH..."
  mkdir -p "${SSH_DIR}"
  chmod 700 "${SSH_DIR}"
  ssh-keygen -t rsa -b 4096 -f "${SSH_DIR}/id_rsa" -N ""
  cat "${SSH_DIR}/id_rsa.pub" >> "${SSH_DIR}/authorized_keys"
  chmod 600 "${SSH_DIR}/authorized_keys"
fi

# (Optionnel) Si vous souhaitez démarrer un service SSHD pour accepter des connexions entrantes,
# décommentez la ligne suivante :
# /usr/sbin/sshd

# Lancer l’entrypoint officiel de PostgreSQL
exec docker-entrypoint.sh "$@"
