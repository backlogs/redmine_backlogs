#/bin/bash

if [[ ! "$WORKSPACE" = /* ]] ||
   [[ ! "$PATH_TO_REDMINE" = /* ]] ||
   [[ ! "$PATH_TO_BACKLOGS" = /* ]];
then
  echo "You should set"\
       " WORKSPACE, PATH_TO_REDMINE, PATH_TO_BACKLOGS"\
       " environment variables"
  exit 1;
fi
if [[ "$REDMINE_VER" = 2 ]];
then
  export PATH_TO_PLUGINS=./plugins # for redmine 2.0
  export GENERATE_SECRET=generate_secret_token
  export MIGRATE_PLUGINS=redmine:plugins:migrate
else
  export PATH_TO_PLUGINS=./vendor/plugins # for redmine < 2.0
  export GENERATE_SECRET=generate_session_store
  export MIGRATE_PLUGINS=db:migrate_plugins
fi

# cd to redmine folder
cd $PATH_TO_REDMINE
echo current directory is `pwd`

# create a link to the backlogs plugin
ln -sf $PATH_TO_BACKLOGS $PATH_TO_PLUGINS/redmine_backlogs

# enable development features
touch backlogs.dev

# install gems
export BUNDLE_GEMFILE=$PATH_TO_REDMINE/Gemfile
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

# enable development features
touch backlogs.dev

# install backlogs
bundle exec rake redmine:backlogs:install labels=no story_trackers=Story task_tracker=Task RAILS_ENV=development --trace

# run backlogs database migrations
bundle exec rake $MIGRATE_PLUGINS RAILS_ENV=test
bundle exec rake $MIGRATE_PLUGINS RAILS_ENV=development

# create a link to cucumber features
ln -sf $PATH_TO_BACKLOGS/features/ .

mkdir -p coverage
ln -sf `pwd`/coverage $WORKSPACE

# patch fixtures
bundle exec rake redmine:backlogs:prepare_fixtures

# run cucumber
if [ ! -n "${CUCUMBER_FLAGS}" ];
then
  export CUCUMBER_FLAGS="--format progress"
fi
bundle exec cucumber $CUCUMBER_FLAGS features

# clean up database
bundle exec rake $MIGRATE_PLUGINS NAME=redmine_backlogs VERSION=0 RAILS_ENV=test
bundle exec rake $MIGRATE_PLUGINS NAME=redmine_backlogs VERSION=0 RAILS_ENV=development

