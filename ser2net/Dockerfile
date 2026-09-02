FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ser2net \
 && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["ser2net"]
CMD ["-n", "-c", "/etc/ser2net/ser2net.yaml"]
