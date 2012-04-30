#!/usr/bin/env ruby

require 'rubygems'
require 'open-uri'
require 'json'

last_version = nil
changelog = File.open('CHANGELOG').each{|line|
  m = line.match(/^== .* (v[0-9]+\.[0-9]+\.[0-9]+)$/)
  if m
    last_version = m[1]
    break
  end
}

gitlog = `git --no-pager log --date=short --format="%ad %s"`
gitlog.split("\n").each{|line|
  line = line.strip

  m = line.match(/^[0-9]{4}-[0-9]{2}-[0-9]{2} (v[0-9]+\.[0-9]+\.[0-9]+)/)
  break if m && m[1] == last_version

  if m
    puts "== #{line}\n"
  else
    issues = line.scan(/#[0-9]+/)
    issues.each{|issueno|
      issue = open("https://api.github.com/repos/relaxdiego/redmine_backlogs/issues/#{issueno.gsub(/^#/, '')}").read
      issue = JSON.parse(issue)
      line.gsub!(/#{issueno}/, "\"#{issue['title']}\"")
    }
    puts "* #{line.gsub(/^[0-9]{4}-[0-9]{2}-[0-9]{2}/, '').strip}"
  end
}

