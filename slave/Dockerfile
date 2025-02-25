FROM postgres:15

# Mise à jour et installation de pgBackRest et des outils SSH
RUN apt-get update && apt-get install -y \
    pgbackrest \
    openssh-client \
    openssh-server && \
    rm -rf /var/lib/apt/lists/*

# Copier le script d’entrypoint personnalisé
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Utiliser notre entrypoint personnalisé
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["postgres"]
