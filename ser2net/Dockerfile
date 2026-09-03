FROM alpine:3.20

RUN apk add --no-cache ser2net

COPY ser2net.conf /etc/ser2net/ser2net.conf

ENTRYPOINT ["ser2net"]
CMD ["-n", "-c", "/etc/ser2net/ser2net.conf"]
