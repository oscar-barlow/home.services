FROM alpine:3.20

RUN apk add --no-cache ser2net

ENTRYPOINT ["ser2net"]
CMD ["-n", "-c", "/etc/ser2net/ser2net.yaml"]
