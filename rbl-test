#!/bin/bash

set -e

function errmsg {
  echo "$1"
  exit 1
}

function print_usage {
cat <<EOF

Usage:
`basename $0`               Run all tests and generate coverage report
`basename $0` -f <feature>  Run tests for a single feature
`basename $0` -h            Show this page
`basename $0` -p            Publish test results to website

EOF
exit $1
}

while getopts "phf:" OPT; do
  case $OPT in
    h) print_usage 0;;
    f) TEST_FEATURE="$OPTARG";;
    p) PUBLISH="yes";;
    [?]) print_usage 1;;
  esac
done

source ~/.backlogs.rc

echo "Running from $PATH_TO_REDMINE"
cd $PATH_TO_REDMINE

echo migrations
bundle exec rake $TRACE generate_secret_token
script -e -c "$PATH_TO_BACKLOGS/redmine20_install.sh -i; $PATH_TO_BACKLOGS/redmine20_install.sh -t" -f ~/redmine/cuke.log

rm -f log/cucumber.log
if [ -z "$TEST_FEATURE" ]; then
  echo "Running all tests"
  script -e -c "cucumber features" -f ~/redmine/cuke.log
else
  echo "Testing feature: $TEST_FEATURE"
  script -e -c "cucumber $TEST_FEATURE" -f ~/redmine/cuke.log
fi

sed '/^$/d' -i ~/redmine/cuke.log

if [ -n "$PUBLISH" ]; then
  cd ~/redmine/redmine_backlogs
  BRANCH=`git branch --no-color | awk '/^\*/ { print $2}'`
  COMMIT=`git log -1 --format=%h`
  COVERAGE="$GEMSET-$BRANCH-$COMMIT"
  rm -rf ~/redmine/www/coverage/$GEMSET-$BRANCH-*

  ran=0
  if [ -e ~/redmine/cuke-$GEMSET.log ]; then
    ran=`grep scenarios ~/redmine/cuke-$GEMSET.log | wc -l`
  fi
  if [ "$ran" = "1" ]; then
    mkdir "$HOME/redmine/www/coverage/$COVERAGE"

    failed=`grep -E 'scenarios.*(skipped|failed)' ~/redmine/cuke-$GEMSET.log | wc -l`

    if [ "$failed" = "1" ]; then
      cd ~/redmine/www/coverage/$COVERAGE
      echo '---' > index.markdown
      echo 'title: Build failed' >> index.markdown
      echo 'layout: default' >> index.markdown
      echo '---' >> index.markdown
      echo '# Build failed' >> index.markdown
      echo '' >> index.markdown
      ruby -e 'while gets; break if $_ =~ /^WARNING/; end; while gets; break if $_ =~ /^[+]-{10}/; puts "    #{$_.strip}  "; end' ~/redmine/cuke-$GEMSET.log >> index.markdown

    else
      cp -r ~/redmine/$GEMSET-$RUBYVER/coverage/* "$HOME/redmine/www/coverage/$COVERAGE"
    fi
  fi

  cd ~/redmine/www/coverage
  echo '---' > index.markdown
  echo 'title: Code coverage' >> index.markdown
  echo 'layout: default' >> index.markdown
  echo '---' >> index.markdown
  echo '# Code coverage' >> index.markdown
  echo '' >> index.markdown
  ls -lt | grep ^d | awk '{print "[" $8, $6, $7 "](" $9 ")  "}' >> index.markdown

  chmod a+rwX ~/redmine/www/coverage/*

  git add .
  git commit -am "coverage update: $COVERAGE"
  git push
fi
