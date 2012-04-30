#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9'
require 'open-uri'
require 'json'

last_version = nil
changelog = File.open('CHANGELOG').each do |line|
  m = line.match(/^== .* (v[0-9]+\.[0-9]+\.[0-9]+)$/)
  if m
    last_version = m[1]
    break
  end
end

gitlog = `git --no-pager log --date=short --format="%ad %s"`
gitlog.split("\n").each do |line|
  line = line.strip

  m = line.match(/^[0-9]{4}-[0-9]{2}-[0-9]{2} (v[0-9]+\.[0-9]+\.[0-9]+)/)
  break if m && m[1] == last_version

  if m
    puts "== #{line}\n"
  else
    issues = line.scan(/#[0-9]+/)
    issues.each do |issueno|
      issue = open("https://api.github.com/repos/relaxdiego/redmine_backlogs/issues/#{issueno.gsub(/^#/, '')}").read
      issue = JSON.parse(issue)
      line.gsub!(/#{issueno}/, "\"#{issue['title']}\"")
    end
    puts "* #{line.gsub(/^[0-9]{4}-[0-9]{2}-[0-9]{2}/, '').strip}"
  end
end

