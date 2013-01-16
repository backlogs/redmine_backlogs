#!/bin/sh
sudo apt-get install pbuilder debootstrap devscripts realpath screen

if [ ! -f phantomjs-1.8.1-linux-x86_64.tar.bz2 ]; then
	curl http://phantomjs.googlecode.com/files/phantomjs-1.8.1-linux-x86_64.tar.bz2 >phantomjs-1.8.1-linux-x86_64.tar.bz2
fi

BINDMOUNTDIR=`realpath $PWD/../..`
cat pbuilderrc.tpl | sed -e "s=__BINDMOUNTDIR__=${BINDMOUNTDIR}=g" > ${HOME}/.pbuilderrc
if [ ! -f $HOME/backlogs_ci/backlogs_ci-base.tgz ]; then
	echo "Creating pbuilder environment. Need to get root, sorry..."
	sudo pbuilder --create
fi


