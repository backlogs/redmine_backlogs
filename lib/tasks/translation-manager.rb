#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'raspell'
require 'iconv'

raise "Ruby 1.9.3 required" unless RUBY_VERSION == '1.9.3' #require psych for utf-8
platform = `rvm-prompt`
if platform == ''
  puts 'Could not detect platform'
  exit
end

m = platform.match(/ruby-([0-9]\.[0-9]).*@(.*)/)
if m.nil?
  puts "Unexpected platform: #{platform}"
  exit
end

HOSTAPP = "#{m[2]}-#{m[1]}"

$jargon = %w{
  backlog
  backlogs
  burn
  burndown
  impediments
  plugin
  point
  points
  product
  rate
  release
  retrospective
  size
  sizes
  stories
  story
  tracker
  trackers
  velocity
  wiki

  #nl
  taakbord

  #de
  Storypunkte
  Erfassungsdatum
  Standartwert
  }

def dir(path=nil)
  path = "/#{path}" if path
  r = ''
  File.expand_path('.', __FILE__).gsub(/\\/, '/').split('/').reject{|d| d == ''}.each {|d|
    r += "/#{d}"
    return "#{r}#{path}" if File.directory?("#{r}/redmine_backlogs")
  }
  return nil
end

$key_order = []
def keycomp(a, b)
  pa = $key_order.index(a)
  pb = $key_order.index(b)

  return pa <=> pb if pa && pb
  return 1 if pa
  return -1 if pb
  return a.to_s <=> b.to_s
end

class Hash
  # sorted keys for cleaner diffs in git
  def to_yaml(opts = {})
    YAML::quick_emit(object_id, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        sort{|a, b| keycomp(a, b) }.each do |k, v|
          map.add(k, v)
        end
      end
    end
  end
end

webdir = dir('www')
Dir.chdir(webdir)
#puts "Updating website"
#puts `git pull`

Dir.chdir(dir('redmine_backlogs'))
webpage = File.open("#{webdir}/_posts/en/1992-01-01-translations.textile", 'w')
translations = dir('redmine_backlogs/config/locales')

$key_order = []
File.open("#{translations}/en.yml").each {|line|
  m = line.match(/^\s+[-_a-z0-9]+\s*:/)
  next unless m
  key = m[0].strip.gsub(/:$/, '').strip
  $key_order << key
}

translation = {}
authors = {}
Dir.glob("#{translations}/*.yml").each {|trans|
  strings = YAML::load_file(trans)
  translation[strings.keys[0]] = strings[strings.keys[0]]
  author = `git log #{trans} | grep -i ^author:`
  author = author.split("\n").collect{|a| a.gsub(/^author:/i, '').gsub(/<.*/, '').strip}
  author = author.uniq.sort{|a, b| a.downcase <=> b.downcase}.join(', ')
  author = " (#{author})" if author != ''
  authors[strings.keys[0]] = author
}

webpage.write(<<HEADER)
---
title: Translations
layout: default
categories: en
---
h1. Translations

*Want to help out with translating Backlogs? Excellent!*

Create an account at "GitHub":http://www.github.com if you don't have one yet. "Fork":https://github.com/backlogs/redmine_backlogs/fork the "Backlogs":http://github.com/backlogs/redmine_backlogs repository, in that repository browse to Source -> config -> locales, click on the translation you want to adapt, en click the "Edit this file" button. Change what you want, and then issue a "pull request":https://github.com/backlogs/redmine_backlogs/pull/new/master, and I'll be able to fetch your changes. The changes will automatically be attributed to you.

The messages below mean the following:

| *Untranslated* | The translation contains words that aspell thinks doesn't belong to that language. |
| *Old-style variable substitution* | the translation uses { { keyword } } instead of %{keyword}. This works for now, but redmine is in the process of phasing it out. |

bq(success). English

serves as a base for all other translations

HEADER

def same(s1, s2)
  return (s1.to_s.strip == s2.to_s.strip) && (s1.to_s.strip.split.size > 2)
end

def translated(l, s)
  status = true
  s = s.gsub(/%\{.+?\}/, ' ').gsub(/\{\{.+?\}\}/, ' ')
  return true if ['zh', 'ja'].include?(l) # aspell doesn't have a language file for these
  speller = Aspell.new(l.gsub('-', '_'))
  speller.set_option('ignore-case', 'true')
  s.gsub(/[^-,\s\.\/:\(\)\?!]+/) do |word|
    next if $jargon.include?(word.downcase)
    #next if Iconv.iconv('ascii//ignore', 'utf-8', word).to_s != word
    unless speller.check(word)
      status = false
      puts "#{l}: #{word}"
    end
  end
  return status
end

def name(t)
  return YAML::load_file("#{dir("#{HOSTAPP}/config/locales")}/#{t}.yml")[t]['general_lang_name']
end

translation.keys.sort.each {|t|
  next if t == 'en'

  untranslated = []
  varstyle = []

  nt = {}
  translation['en'].keys.each {|k|
    nt[k] = translation[t][k].to_s.strip
    nt[k] = translation['en'][k].to_s.strip if nt[k].strip == ''

    varstyle << k if nt[k].include?('{{')
    untranslated << k unless translation['en'][k] != nt[k] || translated(t, nt[k])
  }
  errors = (varstyle + untranslated).uniq

  if errors.size > 0
    pct = " (#{((nt.keys.size - errors.size) * 100) / nt.keys.size}%)"
  else
    pct = ''
  end

  if untranslated.size > 0
    status = 'error'
  elsif varstyle.size > 0
    status = 'warning'
  else
    status = 'success'
  end

  webpage.write("bq(#{status}). #{name(t)}#{pct}#{authors[t]}\n\n")

  columns = 2
  [[untranslated, 'Untranslated'], [varstyle, 'Old-style variable substitution']].each {|error|
    keys, title = *error
    next if keys.size == 0

    webpage.write("*#{title}*\n\n")
    keys.sort!
    while keys.size > 0
      row = (keys.shift(columns) + ['', ''])[0..columns-1]
      webpage.write("|" + row.join("|") + "|\n")
    end

    webpage.write("\n")
  }

  locale_hash = {t => nt}.each_pair{|key,value| [key, value.each_pair {|key,value| [key, value.force_encoding("UTF-8")] }]}
  File.open("#{translations}/#{t}.yml", 'w') { |out| out.write(locale_hash.to_yaml.
  gsub(' !ruby/object:Hash',''). #another psych - emitted yaml will not load again, failing in to_ruby
  gsub('no:','\'no\':') #cannot believe it - psych loads no: as false: !!!
  ) }

}

Dir.chdir(webdir)
#puts "Updating website"
#puts `git add .`
#puts `git commit -m 'Translations updated'`
puts "Now, please update the website"
