#/bin/bash

if [[ -e "$HOME/.backlogs.rc" ]]; then
  source "$HOME/.backlogs.rc"
fi

if [[ -z "$REDMINE_VER" ]]; then
  echo "You have not set REDMINE_VER"
  exit 1
fi

if [[ ! "$WORKSPACE" = /* ]] ||
   [[ ! "$PATH_TO_REDMINE" = /* ]] ||
   [[ ! "$PATH_TO_BACKLOGS" = /* ]];
then
  echo "You should set"\
       " REDMINE_VER, WORKSPACE, PATH_TO_REDMINE, PATH_TO_BACKLOGS"\
       " environment variables"
  echo "You set:"\
       "$WORKSPACE"\
       "$PATH_TO_REDMINE"\
       "$PATH_TO_BACKLOGS"
  exit 1;
fi

case $REDMINE_VER in
  1)  export PATH_TO_PLUGINS=./vendor/plugins # for redmine < 2.0
      export GENERATE_SECRET=generate_session_store
      export MIGRATE_PLUGINS=db:migrate_plugins
      export REDMINE_GIT_REPO=git://github.com/edavis10/redmine.git
      export REDMINE_GIT_TAG=1.4.4
      ;;
  21)  export PATH_TO_PLUGINS=./plugins # for redmine 2.0
      export GENERATE_SECRET=generate_secret_token
      export MIGRATE_PLUGINS=redmine:plugins:migrate
      export REDMINE_GIT_REPO=git://github.com/edavis10/redmine.git
      export REDMINE_GIT_TAG=2.1.0
      ;;
  2)  export PATH_TO_PLUGINS=./plugins # for redmine 2.0
      export GENERATE_SECRET=generate_secret_token
      export MIGRATE_PLUGINS=redmine:plugins:migrate
      export REDMINE_GIT_REPO=git://github.com/edavis10/redmine.git
      export REDMINE_GIT_TAG=2.0.4
      ;;
  m)  export PATH_TO_PLUGINS=./plugins # for redmine 2.0
      export GENERATE_SECRET=generate_secret_token
      export MIGRATE_PLUGINS=redmine:plugins:migrate
      export REDMINE_GIT_REPO=git://github.com/edavis10/redmine.git
      export REDMINE_GIT_TAG=master
      ;;
  cp) export PATH_TO_PLUGINS=./vendor/plugins
      export GENERATE_SECRET=generate_session_store
      export MIGRATE_PLUGINS=db:migrate:plugins
      export REDMINE_GIT_REPO=http://github.com/chiliproject/chiliproject.git
      export REDMINE_GIT_TAG=v3.3.0
      ;;
esac

export BUNDLE_GEMFILE=$PATH_TO_REDMINE/Gemfile

clone_redmine()
{
  set -e # exit if clone fails
  rm -rf $PATH_TO_REDMINE
  if [ ! "$VERBOSE" = "yes" ]; then
    QUIET=--quiet
  fi
  git clone -b master --depth=100 $QUIET $REDMINE_GIT_REPO $PATH_TO_REDMINE
  cd $PATH_TO_REDMINE
  git checkout $REDMINE_GIT_TAG
}

run_tests()
{
  # exit if tests fail
  set -e

  cd $PATH_TO_REDMINE

  # create a link to cucumber features
  ln -sf $PATH_TO_BACKLOGS/features/ .

  mkdir -p coverage
  ln -sf `pwd`/coverage $WORKSPACE

  # patch fixtures
  bundle exec rake redmine:backlogs:prepare_fixtures

  # run cucumber
  if [ ! -n "${CUCUMBER_TAGS}" ];
  then
    CUCUMBER_TAGS="--tags ~@optional"
  fi

  if [ ! -n "${CUCUMBER_FLAGS}" ];
  then
    export CUCUMBER_FLAGS="--format progress ${CUCUMBER_TAGS}"
  fi

  if [ "$1" = "" ]; then
    script -e -c "bundle exec cucumber --no-color $CUCUMBER_FLAGS features" -f $WORKSPACE/cuke.log
  else
    script -e -c "bundle exec cucumber --no-color $CUCUMBER_FLAGS features/$1.feature" -f $WORKSPACE/cuke.log
  fi
  sed '/^$/d' -i $WORKSPACE/cuke.log
  sed 's/$//' -i $WORKSPACE/cuke.log
}

uninstall()
{
  set -e # exit if migrate fails
  cd $PATH_TO_REDMINE
  # clean up database
  bundle exec rake $MIGRATE_PLUGINS NAME=redmine_backlogs VERSION=0 RAILS_ENV=test
  bundle exec rake $MIGRATE_PLUGINS NAME=redmine_backlogs VERSION=0 RAILS_ENV=development
}

run_install()
{
# exit if install fails
set -e

# cd to redmine folder
cd $PATH_TO_REDMINE
echo current directory is `pwd`

# create a link to the backlogs plugin
ln -sf $PATH_TO_BACKLOGS $PATH_TO_PLUGINS/redmine_backlogs

if [ "$DB_TO_RESTORE" = "" ]; then
  export story_trackers=Story
  export task_tracker=Task
else
  DBNAME=`ruby -e "require 'yaml'; puts YAML::load(open('../database.yml'))['test']['database']"`
  DBTYPE=`ruby -e "require 'yaml'; puts YAML::load(open('../database.yml'))['test']['adapter']"`
  if [ "$DBTYPE" = "mysql2" ]; then
    mysqladmin -f -u root -p$DBROOTPW drop $DBNAME
    mysqladmin -u root -p$DBROOTPW create $DBNAME
    mysql -u root -p$DBROOTPW $DBNAME < $DB_TO_RESTORE
  fi
fi

#ignore redmine-master's test-unit dependency, we need 1.2.3
sed -i -e 's=.*gem ["'\'']test-unit["'\''].*==g' ${PATH_TO_REDMINE}/Gemfile
# install gems
mkdir -p vendor/bundle
bundle install --path vendor/bundle

# copy database.yml
cp $WORKSPACE/database.yml config/

# run redmine database migrations
bundle exec rake db:migrate RAILS_ENV=test --trace
bundle exec rake db:migrate RAILS_ENV=development --trace

# install redmine database
bundle exec rake redmine:load_default_data REDMINE_LANG=en RAILS_ENV=development

# generate session store/secret token
bundle exec rake $GENERATE_SECRET

# run backlogs database migrations
bundle exec rake $MIGRATE_PLUGINS RAILS_ENV=test
bundle exec rake $MIGRATE_PLUGINS RAILS_ENV=development

# install backlogs
bundle exec rake redmine:backlogs:install labels=no RAILS_ENV=development --trace
}

while getopts :irtu opt
do case "$opt" in
  r)  clone_redmine; exit 0;;
  i)  run_install;  exit 0;;
  t)  run_tests $2;  exit 0;;
  u)  uninstall;  exit 0;;
  [?]) echo "i: install; r: clone redmine; t: run tests; u: uninstall";;
  esac
done
