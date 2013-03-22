#/bin/bash

trap "cleanup" EXIT

cleanup()
{
  for log in $WORKSPACE/cuke*.log; do
    if [ -f "$log" ]; then
      sed '/^$/d' -i $log # empty lines
      sed 's/$//' -i $log # ^Ms at end of lines
      sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g"  -i $log # ansi coloring
    fi
  done
}

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

export CLUSTER1=" features/updater.feature features/list_with_gaps.feature features/burndown.feature features/cecilia_burndown.feature features/common.feature features/duplicate_story.feature features/extended_timelog.feature features/product_owner.feature features/release3.feature features/release_burndown.feature features/routes.feature features/scrum_master.feature features/settings.feature features/sidebar.feature features/team_member.feature features/ui.feature features/release_burndown_complex.feature"
export CLUSTER2=" features/shared-versions-burndown.feature features/shared-versions-chief_product_owner2.feature features/shared-versions-chief_product_owner.feature features/shared-versions.feature features/shared-versions-pblpage.feature features/shared-versions-positioning.feature features/shared-versions-scrum_master-dnd.feature features/shared-versions-team_member-dnd.feature"

export RAILS_ENV=test
export IN_RBL_TESTENV=true

case $REDMINE_VER in
  1.4.*)  export PATH_TO_PLUGINS=./vendor/plugins # for redmine < 2.0
          export GENERATE_SECRET=generate_session_store
          export MIGRATE_PLUGINS=db:migrate_plugins
          export REDMINE_TARBALL=https://github.com/edavis10/redmine/archive/$REDMINE_VER.tar.gz
          ;;
  2.*)  export PATH_TO_PLUGINS=./plugins # for redmine 2.0
          export GENERATE_SECRET=generate_secret_token
          export MIGRATE_PLUGINS=redmine:plugins:migrate
          export REDMINE_TARBALL=https://github.com/edavis10/redmine/archive/$REDMINE_VER.tar.gz
          ;;
  master) export PATH_TO_PLUGINS=./plugins
          export GENERATE_SECRET=generate_secret_token
          export MIGRATE_PLUGINS=redmine:plugins:migrate
          export REDMINE_GIT_REPO=git://github.com/edavis10/redmine.git
          export REDMINE_GIT_TAG=master
          ;;
  v3.3.0) export PATH_TO_PLUGINS=./vendor/plugins
          export GENERATE_SECRET=generate_session_store
          export MIGRATE_PLUGINS=db:migrate:plugins
          export REDMINE_TARBALL=https://github.com/chiliproject/chiliproject/archive/$REDMINE_VER.tar.gz
          ;;
  *)      echo "Unsupported platform $REDMINE_VER"
          exit 1
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
  if [ -n "${REDMINE_GIT_TAG}" ]; then
    git clone -b $REDMINE_GIT_TAG --depth=100 $QUIET $REDMINE_GIT_REPO $PATH_TO_REDMINE
    cd $PATH_TO_REDMINE
    git checkout $REDMINE_GIT_TAG
  else
    mkdir -p $PATH_TO_REDMINE
    wget $REDMINE_TARBALL -O- | tar -C $PATH_TO_REDMINE -xz --strip=1 --show-transformed -f -
  fi
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

  if [ "$VERBOSE" = "yes" ]; then
    TRACE=--trace
  fi
  # patch fixtures
  bundle exec rake redmine:backlogs:prepare_fixtures $TRACE

  # run cucumber
  if [ ! -n "${CUCUMBER_TAGS}" ];
  then
    CUCUMBER_TAGS="--tags ~@optional"
  fi

  if [ ! -n "${CUCUMBER_FLAGS}" ]; then
    if [ "$VERBOSE" = "yes" ]; then
      export CUCUMBER_FLAGS="${CUCUMBER_TAGS}"
    else
      export CUCUMBER_FLAGS="--format progress ${CUCUMBER_TAGS}"
    fi
  fi

  FEATURE=$1
  if [ ! -e "$FEATURE" ]; then
    FEATURE="features/$FEATURE.feature"
  fi
  if [ ! -e "$FEATURE" ]; then
    FEATURE=""
  fi

  if [ -n "$CLUSTER" ]; then
    eval TESTS="\$$CLUSTER"
    LOG="$WORKSPACE/cuke.cluster.log"
  elif [ -e "$FEATURE" ]; then
    TESTS="$FEATURE"
    LOG=`basename $FEATURE`
    LOG="$WORKSPACE/cuke.$LOG.log"
  else
    TEST="features"
    LOG=$WORKSPACE/cuke.log
  fi

  script -e -c "bundle exec cucumber $CUCUMBER_FLAGS $TESTS" -f $LOG
}

uninstall()
{
  set -e # exit if migrate fails
  cd $PATH_TO_REDMINE
  # clean up database
  if [ "$VERBOSE" = "yes" ]; then
    TRACE=--trace
  fi
  bundle exec rake $TRACE $MIGRATE_PLUGINS NAME=redmine_backlogs VERSION=0
}

run_install()
{
# exit if install fails
set -e

# cd to redmine folder
cd $PATH_TO_REDMINE
echo current directory is `pwd`

# create a link to the backlogs plugin, but avoid recursive link.
if [ -L "$PATH_TO_PLUGINS/redmine_backlogs" ]; then rm "$PATH_TO_PLUGINS/redmine_backlogs"; fi
ln -s "$PATH_TO_BACKLOGS" "$PATH_TO_PLUGINS/redmine_backlogs"

# copy database.yml
cp $WORKSPACE/database.yml config/
if [ "$RUBYVER" = "1.8" ]; then
  sed -i -e 's/mysql2/mysql/g' config/database.yml
fi

export DBNAME=`ruby -e "require 'yaml'; puts YAML::load(open('config/database.yml'))['$RAILS_ENV']['database']"`
export DBTYPE=`ruby -e "require 'yaml'; puts YAML::load(open('config/database.yml'))['$RAILS_ENV']['adapter']"`

if [ "$CLEARDB" = "yes" ]; then
  if [ "$DBTYPE" = "mysql2" ] || [ "$DBTYPE" = "mysql" ]; then
    mysqladmin -f -u root -p$DBROOTPW drop $DBNAME
    mysqladmin -u root -p$DBROOTPW create $DBNAME
  fi
  if [ "$DBTYPE" = "postgresql" ] ; then
    echo "drop database if exists $DBNAME" | psql postgres root
    echo "create database $DBNAME" | psql postgres root
  fi
fi

if [ "$DB_TO_RESTORE" = "" ]; then
  export story_trackers=Story
  export task_tracker=Task
else
  if [ "$DBTYPE" = "mysql2" ] || [ "$DBTYPE" = "mysql" ]; then
    mysqladmin -f -u root -p$DBROOTPW drop $DBNAME
    mysqladmin -u root -p$DBROOTPW create $DBNAME
    mysql -u root -p$DBROOTPW $DBNAME < $DB_TO_RESTORE
  fi
  if [ "$DBTYPE" = "postgresql" ] ; then
    echo "drop database if exists $DBNAME" | psql postgres root
    echo "create database $DBNAME" | psql postgres root
    psql $DBNAME root < $DB_TO_RESTORE
  fi
fi

# Workarounds for test-unit versions, for Rails 2 - e.g in case we still support Chiliproject.
# TODO: review if this is only for CP, if so remove this and adjust condition in our Gemfile
# 20130120 patrick: using test-unit > 1.2.3 has the complete dependency hell going to cucumber.
# 1) ignore redmine-master's test-unit dependency, we need 1.2.3..
sed -i -e 's=.*gem ["'\'']test-unit["'\''].*==g' ${PATH_TO_REDMINE}/Gemfile
# 2) tell out Gemfile that we're testing: so force test-unit 1.2.3 #done globally above by setting IN_RBL_TESTENV=true
#capybara 2 breaks our tests. too much has changed.
sed -i -e 's=.*gem ["'\'']capybara["'\''].*==g' ${PATH_TO_REDMINE}/Gemfile

# install gems
mkdir -p vendor/bundle
bundle install --path vendor/bundle

if [ "$DBTYPE" = "mysql" -a "$RUBYVER" = "1.8" ] ; then
  bundle exec gem install -v=2.8.1 mysql
  echo y | bundle exec gem uninstall -v=2.9.0 mysql
  echo 'boing'
fi

sed -i -e 's/fail "GONE"/#fail "GONE"/' `find . -type f -exec grep -l 'fail "GONE"' {} \;` README.rdoc

if [ "$VERBOSE" = "yes" ]; then echo 'Gems installed'; fi

if [ "$VERBOSE" = "yes" ]; then
  export TRACE=--trace
fi

# run redmine database migrations
if [ "$VERBOSE" = "yes" ]; then echo 'Migrations'; fi
bundle exec rake db:migrate $TRACE

# install redmine database
if [ "$VERBOSE" = "yes" ]; then echo 'Load defaults'; fi
bundle exec rake redmine:load_default_data REDMINE_LANG=en $TRACE

if [ "$VERBOSE" = "yes" ]; then echo 'Tokens'; fi
# generate session store/secret token
bundle exec rake $GENERATE_SECRET $TRACE

# run backlogs database migrations
if [ "$VERBOSE" = "yes" ]; then echo 'Plugin migrations'; fi
bundle exec rake $MIGRATE_PLUGINS $TRACE

# install backlogs
if [ "$VERBOSE" = "yes" ]; then echo 'Backlogs install'; fi
bundle exec rake redmine:backlogs:install labels=no $TRACE

if [ "$VERBOSE" = "yes" ]; then echo 'Done!'; fi
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
