# dcape-app-pg-backup

[![GitHub Release][1]][2] [![GitHub code size in bytes][3]]() [![GitHub license][4]][5]

[1]: https://img.shields.io/github/release/dopos/dcape-app-pg-backup.svg
[2]: https://github.com/dopos/dcape-app-pg-backup/releases
[3]: https://img.shields.io/github/languages/code-size/dopos/dcape-app-pg-backup.svg
[4]: https://img.shields.io/github/license/dopos/dcape-app-pg-backup.svg
[5]: LICENSE

Postgresql database backup application package for [dcape](https://github.com/dopos/dcape) v3.

## Docker image used

* dcape v1: none (used running dcape_db container)
* dcape v2: internally built image with name stored in ${DCAPE_COMPOSE} drone var
* dcape v3: dcape-compose (cron uses running dcape_db container)

## Requirements

* linux 64bit (git, make, wget, gawk, openssl)
* [docker](http://docker.io)
* [dcape](https://github.com/dopos/dcape) v3
* Git service ([github](https://github.com), [gitea](https://gitea.io) or [gogs](https://gogs.io))

## Usage

* Fork this repo in your Git service
* Setup deploy hook
* Run "Test delivery" (config sample will be created in dcape)
* Edit and save config (enable deploy etc)
* Run "Test delivery" again (app will be installed and started on webhook host)

See also: [Deploy setup](https://github.com/dopos/dcape/blob/master/DEPLOY.md) (in Russian)

## Direct run

If installed via CI/CD
```
docker exec -ti pg-backup-cron-1 bash -c 'cd /root && /etc/periodic/daily/pgbackup.sh'
```
If installed locally
```
make backup
```

## License

The MIT License (MIT), see [LICENSE](LICENSE).

Copyright (c) 2017-2023 Aleksei Kovrizhkin <lekovr+dopos@gmail.com>
