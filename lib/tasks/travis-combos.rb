#!/usr/bin/env ruby

require 'yaml'
require 'pp'

travis = YAML::load_file('.travis.yml')

af = (travis['rvm'].collect{|rvm| {'rvm' => rvm}} + travis['env'].collect{|env| {'env' => env}}) - travis['matrix']['allow_failures']
pp af

possibilities = []
travis['rvm'].each{|rvm|
  travis['env'].each{|env|
    possibilities << {'rvm' => rvm, 'env' => env}
  }
}

exc = possibilities - travis['matrix']['exclude']
pp exc

#language: ruby
#rvm:
#  - 1.8.7
#  - 1.9.3
#  - jruby-18mode
#  - jruby-19mode
#env:
#  - REDMINE_VER=1
#  - REDMINE_VER=203
#  - REDMINE_VER=204
#  - REDMINE_VER=21
#  - REDMINE_VER=m
#  - REDMINE_VER=cp
#matrix:
#  allow_failures:
#    - rvm: jruby-18mode
#    - rvm: 1.8.7
#    - env: REDMINE_VER=1
#    - env: REDMINE_VER=m
#    - env: REDMINE_VER=cp
#  exclude:
#    - rvm: jruby-18mode
#      env: REDMINE_VER=203
#    - rvm: jruby-18mode
#      env: REDMINE_VER=204
#    - rvm: jruby-18mode
#      env: REDMINE_VER=21
#    - rvm: 1.8.7
#      env: REDMINE_VER=cp
#    - rvm: jruby-18mode
#      env: REDMINE_VER=cp
#
#install: "echo skip bundle install"
#
#script:
#  - export WORKSPACE=`pwd`/workspace
#  - export PATH_TO_BACKLOGS=`pwd`
#  - export PATH_TO_REDMINE=$WORKSPACE/redmine
#  - mkdir $WORKSPACE
#  - cp config/database.yml.travis $WORKSPACE/database.yml
#  - bash -x ./redmine20_install.sh -r
#  - bash -x ./redmine20_install.sh -i
#  - bash -x ./redmine20_install.sh -t
#  - bash -x ./redmine20_install.sh -u
#
