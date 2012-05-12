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

# cd to redmine folder
echo changing directory to $PATH_TO_REDMINE
cd $PATH_TO_REDMINE
echo current directory is `pwd`

# create a link to the backlogs plugin
echo creating a symbolic link ./plugins/redmine_backlogs to $PATH_TO_BACKLOGS
ln -sf $PATH_TO_BACKLOGS ./plugins/redmine_backlogs

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
bundle exec rake generate_secret_token
# bundle exec rake generate_session_store # for redmine < 2.0

# install backlogs
bundle exec rake redmine:backlogs:install labels=no story_tracker=Story task_tracker=Task RAILS_ENV=development --trace

# run backlogs database migrations
bundle exec rake redmine:plugins:migrate RAILS_ENV=test
bundle exec rake redmine:plugins:migrate RAILS_ENV=development

# create a link to cucumber features
ln -sf $PATH_TO_BACKLOGS/features/ .

# enable development features
touch backlogs.dev

mkdir -p coverage
ln -sf `pwd`/coverage $WORKSPACE

# run cucumber
if [ ! -n "${CUCUMBER_FLAGS}" ];
then
  export CUCUMBER_FLAGS="--format progress"
fi
bundle exec cucumber $CUCUMBER_FLAGS features

# clean up database
bundle exec rake redmine:plugins:migrate NAME=redmine_backlogs VERSION=0 RAILS_ENV=test
bundle exec rake redmine:plugins:migrate NAME=redmine_backlogs VERSION=0 RAILS_ENV=development

