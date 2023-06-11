FROM flyway/flyway:9

COPY flyway.conf .
COPY sql/ sql/
COPY ./wait-for-it.sh .

ENTRYPOINT [ "./wait-for-it.sh", "192.168.1.204:5432", "--", "./flyway", "migrate" ]
