#/bin/bash

if [ ! -n "${WORKSPACE}" ] ||
   [ ! -n "${PATH_TO_REDMINE}" ] ||
   [ ! -n "${PATH_TO_BACKLOGS}" ];
then
  echo "You should set"\
       " WORKSPACE, PATH_TO_REDMINE, PATH_TO_BACKLOGS"\
       " environment variables"
  exit 1;
fi

# cd to redmine folder
cd $PATH_TO_REDMINE

# create a link to the backlogs plugin
ln -sf ../$PATH_TO_BACKLOGS plugins/redmine_backlogs

# install gems
bundle install --path vendor/bundle

# copy database.yml
cp $WORKSPACE/database.yml config/

# run redmine database migrations
rake db:migrate RAILS_ENV=test --trace
rake db:migrate RAILS_ENV=development --trace

# install redmine database
REDMINE_LANG=en RAILS_ENV=development rake redmine:load_default_data

# install backlogs
rake redmine:backlogs:install labels=no story_trackers=Story task_tracker=Task override_unsupported=true RAILS_ENV=development --trace

# run backlogs database migrations
rake redmine:plugins:migrate RAILS_ENV=test
rake redmine:plugins:migrate RAILS_ENV=development

# create a link to cucumber features
ln -sf $PATH_TO_BACKLOGS/features/ .

# enable development features
touch backlogs.dev

mkdir -p coverage
ln -sf `pwd`/coverage $WORKSPACE

# run cucumber
bundle exec cucumber -f junit --out $WORKSPACE

# clean up database
rake redmine:plugins:migrate NAME=redmine_backlogs VERSION=0 RAILS_ENV=test
rake redmine:plugins:migrate NAME=redmine_backlogs VERSION=0 RAILS_ENV=development

