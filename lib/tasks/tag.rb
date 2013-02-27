#!/usr/bin/env ruby

require 'yaml'
require 'pp'

tag = true

`git fetch --tags`
  
tags = `git tag`.split("\n")
  
versions = {}

tags.each {|version|
  m = version.match(/^v([0-9]+)\.([0-9]+)\.([0-9]+)$/)
  raise "Unexpected version #{version.inspect}" unless m
  parts = 1.upto(3).collect{|i| Integer(m[i])}
  key = parts.collect{|p| p.to_s.rjust(5, '0')}.join('.')
  versions[key] = {:string => version, :parts => parts}

  `git tag -d #{version}`
  #`git push origin :refs/tags/#{version}`
}
  
newversion = versions[versions.keys.sort[-1]][:parts]

if ARGV[0].nil?
  level = 2
else
  level = Integer(ARGV[0])
  raise "Unexpected level #{ARGV[0]}" if level < 0 || level > 2
end
  
newversion[level] += 1
(level + 1).upto(2) {|l| newversion[l] = 0}
  
newversion = 'v' + newversion.collect{|p| p.to_s}.join('.')

changelog = `grep '^== .* #{newversion}' CHANGELOG.rdoc`
if changelog == '' && tag
  puts "CHANGELOG.rdoc not up to date for #{newversion}"
  exit
end
  
authors = `git shortlog -s -n | head -8`.split("\n").collect{|l| l.gsub(/^\s*[0-9]+\s*/, '').gsub(/"/, "'") }
  
code = nil
File.open('init.rb') do |f|
  code = f.read
end
code.gsub!(/version\s+'[^']+'/m, "version '#{newversion}'")
code.gsub!(/author\s+'[^']+'/m, "author \"#{authors}\"")
File.open('init.rb', 'w') do |f|
  f.write(code)
end

dot_travis = File.join(File.dirname(__FILE__), '..', '..', '.travis.yml')
travis = YAML::load(File.open(dot_travis).read)
travis['release'] = newversion.gsub(/^v/, '')
File.open(dot_travis, 'w') { |out| out.write(travis.to_yaml) }

puts "Tagging #{newversion}"
if tag
  `git add .travis.yml init.rb CHANGELOG.rdoc`
  `git commit -m #{newversion}`
  `git tag #{newversion}`
  `git push`
  `git push --tags`
end

newversion = 'v' + newversion.collect{|p| p.to_s}.join('.') if newversion.is_a?(Array)

Dir.chdir('../www')
`git pull`

File.open('_includes/version.html', 'w') { |f| f.write(newversion) }

`git add _includes/version.html`
`git commit -m #{newversion}`
`git push`
