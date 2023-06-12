FROM flyway/flyway:9

COPY flyway.conf .
COPY ./wait-for-it.sh .
COPY sql/ sql/

ENTRYPOINT [ "./flyway", "migrate" ]
