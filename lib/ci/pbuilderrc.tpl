# build user id must not exist on the host system
BUILDUSERID=1234
# where most stuff takes place
BASE=$HOME/backlogs_ci
NAME=backlogs_ci

BUILDUSERNAME=backlogs
BASETGZ="$BASE/$NAME-base.tgz"
BUILDRESULT="$BASE/$NAME/result/"
BUILDPLACE="$BASE/build/"
APTCACHE="$BASE/$NAME/aptcache/"
APTCACHEHARDLINK=no
OTHERMIRROR="deb http://de.archive.ubuntu.com/ubuntu/ precise-updates main restricted universe multiverse"
COMPONENTS="main restricted universe multiverse"
EXTRAPACKAGES="less curl wget git-core autoconf bison build-essential git-core imagemagick libcurl4-openssl-dev libssl-dev libxml2-dev libxslt1-dev libyaml-dev openssl zlib1g zlib1g-dev libmagickwand4 libmagickwand-dev libgraphicsmagick1-dev libmysqlclient-dev libpq-dev libsqlite3-dev mysql-server postgresql"
BINDMOUNTS="__BINDMOUNTDIR__"
