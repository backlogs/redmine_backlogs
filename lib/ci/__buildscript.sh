#!/bin/bash
echo
echo
echo
echo "Building ruby ${RVM} db ${DB} redmine ${REDMINE_VER}"
echo
echo
export HOME=/home/backlogs-build
mkdir -p ${HOME}
cd ${HOME}
echo "Installing prerequisites"
apt-get -y install \
	less curl wget \
	git-core autoconf bison build-essential git-core imagemagick libcurl4-openssl-dev libssl-dev libxml2-dev libxslt1-dev libyaml-dev openssl zlib1g zlib1g-dev libmagickwand4 libmagickwand-dev libgraphicsmagick1-dev libmysqlclient-dev libpq-dev libsqlite3-dev 

case $DB in
	mysql)
		apt-get -y install mysql-server
		sed -i -e 's=bind-address.*=skip-networking=' /etc/mysql/my.cnf
		service mysql start
		mysql -e 'create database IF NOT EXISTS backlogs;'
		;;
	postgresql)
		apt-get -y install postgresql
		sed -i -e 's=peer=trust=g' /etc/postgresql/9.1/main/pg_hba.conf
		sed -i -e 's/port.*/port=5432/g' /etc/postgresql/9.1/main/postgresql.conf
		sed -i -e "s/#listen_addresses.*/listen_addresses=''/g" /etc/postgresql/9.1/main/postgresql.conf
		
		service postgresql start
		psql -c 'DROP DATABASE IF EXISTS backlogs;' -U postgres
		psql -c 'create database backlogs;' -U postgres
		;;
esac

echo "Installing ruby"
case $RVM in
	1.9.3)
		apt-get -y install ruby1.9.3 ruby1.9.1-dev
		;;
	1.8.7)
		apt-get -y install ruby1.8 ruby1.8-dev rubygems
		;;
	*)
		echo "unknown RVM";exit 1;;
esac
gem install bundler
export TRAVIS_RUBY_VERSION=${RVM}
export PATH=/usr/local/bin:${PATH}

echo "Installing phantomjs"
cd ${HOME}
tar -xjf $BINDMOUNTDIR/lib/ci/phantomjs-1.8.1-linux-x86_64.tar.bz2
ln -s `pwd`/phantomjs-*/bin/phantomjs /usr/bin/phantomjs

export WORKSPACE=${HOME}/workspace
export PATH_TO_REDMINE=${WORKSPACE}/redmine
export PATH_TO_BACKLOGS=${HOME}/redmine_backlogs
mkdir -p ${WORKSPACE}

cd ${HOME}
git clone $BINDMOUNTDIR redmine_backlogs
cd redmine_backlogs
cp config/database.yml.travis ${WORKSPACE}/database.yml

./redmine_install.sh -r || exit 1
./redmine_install.sh -i || exit 1
./redmine_install.sh -t || exit 1
./redmine_install.sh -u || exit 1
exit 0

