## dcape-app-pg-backup Makefile:
## Backup pg databases via docker container with crond
#:
SHELL      = /bin/sh
CFG       ?= .env

BACKUP_ENABLED  ?= no
DB_NAME         ?= template1
BACKUP_CRON     ?= 10 5 * * *

DCAPE_COMPOSE   ?= dcape_drone-compose
DC_VER          ?= latest

# dcape v1 compat
ifdef DCAPE_PROJECT_NAME
    APP_TAG         := $(DCAPE_PROJECT_NAME)
else
    APP_TAG         ?= pg-backup
endif
ifdef DCAPE_DB
    PG_CONTAINER    := $(DCAPE_DB)
else
    PG_CONTAINER    ?= dcape_db_1
endif

# ------------------------------------------------------------------------------
define CONFIG_DEF
# dcape-app-backup-pg settings

# Process backups
BACKUP_ENABLED=$(BACKUP_ENABLED)

# Backup database name(s)
DB_NAME=$(DB_NAME)

# Cron args
BACKUP_CRON=$(BACKUP_CRON)

endef
export CONFIG_DEF

# ------------------------------------------------------------------------------
# Create script
# DCAPE_DB_DUMP_DEST must be set in pg container

define EXP_SCRIPT
[ "$$DCAPE_DB_DUMP_DEST" ] || { echo "DCAPE_DB_DUMP_DEST not set. Exiting" ; exit 1 ; } ; \
DBS=$$@ ; \
[[ "$$DBS" ]] || DBS=all ; \
dt=$$(date +%y%m%d) ; \
if [[ $$DBS == "all" ]] ; then \
  echo "Exporting all databases..." ; \
  DBS=$$(psql --tuples-only -P format=unaligned -U postgres \
    -c "SELECT datname FROM pg_database WHERE NOT datistemplate AND datname <> 'postgres'") ; \
fi ; \
echo "Backup DBs: $$DBS" ; \
for d in $$DBS ; do \
  dest=$$DCAPE_DB_DUMP_DEST/$${d%%.*}-$${dt}.tgz ; \
  echo -n $${dest}... ; \
  [ -f $$dest ] && { echo Skip ; continue ; } ; \
  pg_dump -d $$d -U postgres -Ft | gzip > $$dest || echo "error" ; \
  echo Done ; \
done
endef
export EXP_SCRIPT

# ------------------------------------------------------------------------------

-include $(CFG)
export

.PHONY: all $(CFG) start start-hook stop update docker-wait cron backup help

all: help

# ------------------------------------------------------------------------------
## dcape v1 deploy targets
#:

## create crontab record and run backup
start-hook: cron backup

## remove cron
stop: cleanup

## run backup
update: backup

## dcape v1 operations
#:

## Setup host system cron
cron: /etc/cron.d/backup

/etc/cron.d/backup:
	echo "$$BACKUP_CRON op cd $$PWD && make backup" > $@

## Clean host system cron
cleanup:
	[ -f /etc/cron.d/backup ] && rm /etc/cron.d/backup || true


# ------------------------------------------------------------------------------
# docker

# Wait for postgresql container start
docker-wait:
	@echo -n "Checking PG is ready..."
	@until [ `docker inspect -f "{{.State.Health.Status}}" $$PG_CONTAINER` = "healthy" ] ; do sleep 1 ; echo -n "." ; done
	@echo "Ok"

# ------------------------------------------------------------------------------
## DB operations
#:

## dump all databases or named database
backup: docker-wait
	@echo "*** $@ ***"
	@if [ "$$BACKUP_ENABLED" = "yes" ] ; then echo "$$EXP_SCRIPT" | docker exec -i $$PG_CONTAINER bash -s - $$DB_NAME ; else echo Disabled ; fi

# -----------------------------------------------------------------------------

# Run app inside drone
# Used in .drone.yml
# Do not use outside
.drone-up:
	@echo "*** $@ ***"
	@[ "$$PWD" = "$(APP_ROOT)" ] && { echo "APP_ROOT == PWD, so we're not inside drone. Aborting" ; exit 1 ; } || true
	@docker-compose -p "$(APP_TAG)" up --force-recreate --build -d


# -----------------------------------------------------------------------------
## Docker-compose commands
#:

## (re)start container
up:
up: CMD=up --force-recreate --build -d
up: dc

## stop (and remove) container
down:
down: CMD=rm -f -s
down: dc

# $$PWD usage allows host directory mounts in child containers
# Thish works if path is the same for host, docker, docker-compose and child container
## run $(CMD) via docker-compose
dc: docker-compose.yml
	@docker run --rm  -i \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $$PWD:$$PWD -w $$PWD \
  -e DCAPE_COMPOSE \
  docker/compose:$$DC_VER \
  -p $$APP_TAG --env-file $(CFG) \
  $(CMD)

# ------------------------------------------------------------------------------
## Other
#:

## create initial config
$(CFG).sample:
	@echo "$$CONFIG_DEF" > $@
	@echo "$@ Created. Edit and rename to $(CFG)"

## generate sample config
config: $(CFG).sample

# ------------------------------------------------------------------------------

# This code handles group header and target comment with one or two lines only
## list Makefile targets
## (this is default target)
help:
	@grep -A 1 -h "^## " $(MAKEFILE_LIST) \
  | sed -E 's/^--$$// ; /./{H;$$!d} ; x ; s/^\n## ([^\n]+)\n(## (.+)\n)*(.+):(.*)$$/"    " "\4" "\1" "\3"/' \
  | sed -E 's/^"    " "#" "(.+)" "(.*)"$$/"" "" "" ""\n"\1 \2" "" "" ""/' \
  | xargs printf "%s\033[36m%-15s\033[0m %s %s\n"
