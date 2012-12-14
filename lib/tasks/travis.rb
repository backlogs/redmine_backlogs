#!/usr/bin/env ruby

require 'yaml'
require 'pp'

travis = YAML::load_file('.travis.yml')

vers = ARGV
#travis['env'].each{|env|
#  vers << env.split[0]
#}
travis['env'] = []

vers.each{|ver|
  Dir['features/*.feature'].collect{|feature| File.basename(feature, File.extname(feature))}.sort.each{|feature|
    travis['env'] << "REDMINE_VER=#{ver} FEATURE=#{feature} RAILS_ENV=test"
  }
}

File.open('.travis.yml', 'w'){|f| f.write(travis.to_yaml)}

