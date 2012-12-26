#!/usr/bin/env ruby

require 'rubygems'
require 'open-uri'
require 'json'

last_version = nil
changelog = File.open('CHANGELOG.rdoc').each{|line|
  m = line.match(/^== .* (v[0-9]+\.[0-9]+\.[0-9]+)$/)
  if m
    last_version = m[1]
    break
  end
}

puts "== #{Date.today.strftime('%Y-%m-%d')} v???\n\n"
gitlog = `git --no-pager log -50 --date=short --format="%ad %s"`
gitlog.split("\n").each{|line|
  line = line.strip

  m = line.match(/^[0-9]{4}-[0-9]{2}-[0-9]{2} (v[0-9]+\.[0-9]+\.[0-9]+)/)
  break if m && m[1] == last_version

  if m
    puts "\n== #{line}\n\n"
  else
    issues = line.scan(/#[0-9]+/)
    issues.each{|issueno|
      issue = open("https://api.github.com/repos/backlogs/redmine_backlogs/issues/#{issueno.gsub(/^#/, '')}").read
      issue = JSON.parse(issue)
      line.gsub!(/#{issueno}/, "\"#{issue['title']}\"")
    }
    puts "* #{line.gsub(/^[0-9]{4}-[0-9]{2}-[0-9]{2}/, '').strip}"
  end
}

puts "\n"

puts File.open('CHANGELOG.rdoc').read
