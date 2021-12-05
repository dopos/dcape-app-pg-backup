ARG DCAPE_COMPOSE

FROM $DCAPE_COMPOSE

ARG BACKUP_CRON

MAINTAINER Alexey Kovrizhkin <lekovr+dopos@gmail.com>

ENV DOCKERFILE_VERSION  20211205

RUN apk add --no-cache busybox-initscripts

COPY Makefile /root/

# Show timings in ENV data (ReadOnly)
ENV CRONTAB $BACKUP_CRON

RUN echo "$BACKUP_CRON    make backup" > /etc/crontabs/root

ENTRYPOINT []

CMD ["crond", "-l", "2", "-f"]
