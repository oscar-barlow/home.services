FROM flyway/flyway:7.0

COPY flyway.conf .
COPY sql/ sql/
COPY ./wait-for-it.sh .

ENTRYPOINT [ "./wait-for-it.sh", "db:5432", "--", "./flyway", "migrate" ]