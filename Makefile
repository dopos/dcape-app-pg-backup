# dcape-app-pg-backup Makefile

SHELL               = /bin/bash
CFG                ?= .env

# Process backups
BACKUP_ENABLED     ?= no
# Backup database name(s)
DB_NAME            ?= template1
# Cron args
BACKUP_CRON        ?= 10 5 * * *

# dcape container name prefix
DCAPE_PROJECT_NAME ?= dcape
# dcape postgresql container name
DCAPE_DB           ?= $(DCAPE_PROJECT_NAME)_db_1

define CONFIG_DEF
# ------------------------------------------------------------------------------
# dcape-app-backup-pg settings

# Process backups
BACKUP_ENABLED=$(BACKUP_ENABLED)

# Backup database name(s)
DB_NAME=$(DB_NAME)
# Cron args
BACKUP_CRON=$(BACKUP_CRON)

# dcape postgresql container name
DCAPE_DB=$(DCAPE_DB)

endef
export CONFIG_DEF

# ------------------------------------------------------------------------------
# Create script
# DCAPE_DB_DUMP_DEST must be set in pg container

define EXP_SCRIPT
[[ "$$DCAPE_DB_DUMP_DEST" ]] || { echo "DCAPE_DB_DUMP_DEST not set. Exiting" ; exit 1 ; } ; \
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

##
## Цели:
##

all: help

# ------------------------------------------------------------------------------
# webhook commands

start-hook: cron backup

stop: cleanup

update: backup

# ------------------------------------------------------------------------------
# docker

# Wait for postgresql container start
docker-wait:
	@echo -n "Checking PG is ready..."
	@until [[ `docker inspect -f "{{.State.Health.Status}}" $$DCAPE_DB` == healthy ]] ; do sleep 1 ; echo -n "." ; done
	@echo "Ok"

# ------------------------------------------------------------------------------
# DB operations

## Setup host system cron
cron: /etc/cron.d/backup

/etc/cron.d/backup:
	echo "$$BACKUP_CRON op cd $$PWD && make backup" > $@

## dump all databases or named database
backup: docker-wait
	@echo "*** $@ ***"
	@[[ "$$BACKUP_ENABLED" == "yes" ]] && echo "$$EXP_SCRIPT" | docker exec -i $$DCAPE_DB bash -s - $$DB_NAME

cleanup:
	[ -f /etc/cron.d/backup ] && rm /etc/cron.d/backup || true

# ------------------------------------------------------------------------------

## create initial config
$(CFG):
	@[ -f $@ ] || echo "$$CONFIG_DEF" > $@

# ------------------------------------------------------------------------------

## List Makefile targets
help:
	@grep -A 1 "^##" Makefile | less

##
## Press 'q' for exit
##
