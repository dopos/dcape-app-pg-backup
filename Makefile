## dcape-app-pg-backup Makefile:
## Backup pg databases via docker container with crond
#:
SHELL      = /bin/sh
CFG       ?= .env

#- Enable work
BACKUP_ENABLED  ?= no
#- DB names
DB_NAME         ?= template1
#- Cron rules
BACKUP_CRON     ?= 10 5 * * *
#- project name
APP_TAG         ?= pg-backup
#- container name
PG_CONTAINER    ?= dcape_db_1

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
# Find and include DCAPE_ROOT/Makefile
DCAPE_COMPOSE   ?= dcape-compose
DCAPE_ROOT      ?= $(shell docker inspect -f "{{.Config.Labels.dcape_root}}" $(DCAPE_COMPOSE))

ifeq ($(shell test -e $(DCAPE_ROOT)/Makefile.app && echo -n yes),yes)
  include $(DCAPE_ROOT)/Makefile.app
else
  include /opt/dcape/Makefile.app
endif

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
	@docker compose -p "$(APP_TAG)" up --force-recreate --build -d

