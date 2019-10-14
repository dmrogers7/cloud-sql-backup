FROM google/cloud-sdk:alpine

RUN mkdir /app

COPY ./backup.sh /app/backup.sh
COPY ./vault-get-creds.sh /app/vault-get-creds.sh

RUN chmod +x /app/*.sh
RUN echo hello

CMD /app/backup.sh
