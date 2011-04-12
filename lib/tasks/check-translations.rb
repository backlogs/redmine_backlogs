#!/usr/bin/env ruby

require 'yaml'

language_name = {
  'de' => 'German', 
  'en-GB' => 'UK English',
  'en' => 'US English',
  'fr' => 'French',
  'nl' => 'Dutch',
  'pt-BR' => 'Brazilian Portuguese',
  'ru' => 'Russian',
  'zh' => 'Chinese',
}

webdir = File.join(File.dirname(__FILE__), '..', '..', '..', 'www.redminebacklogs.net')

diffs = File.join(File.dirname(__FILE__), 'lang-diffs')

$logfile = nil
if File.directory? webdir
    $logfile = File.open(File.join(webdir, '_posts', 'en', '1992-01-01-translations.textile'), 'w')
end

def log(s)
    puts s
    $logfile.puts(s) if $logfile
end

langdir = File.join(File.dirname(__FILE__), '..', '..', 'config', 'locales')

template_file = "#{langdir}/en.yml"
template = YAML::load_file(template_file)['en']

log """---
title: Translations
layout: default
categories: en
---
h1. Translations

bq(success). US English

serves as a base for all other translations

"""

Dir.glob("#{langdir}/*.yml").sort.each {|lang_file|
  next if lang_file == template_file

  lang = YAML::load_file(lang_file)
  l = lang.keys[0]
  language = language_name[l] || l

  missing = []
  obsolete = []
  varstyle = []

  missing = (template.keys - lang[l].keys) + template.keys.select{|k| lang[l][k] && lang[l][k] =~ /^\[\[.*\]\]$/}
  obsolete = lang[l].keys - template.keys
  varstyle = template.keys.select{|k| lang[l][k] && lang[l][k].include?('{{') }

  if File.directory? diffs
    diff = {}
    missing.each {|key|
      diff[key] = template[key]
    }
    File.open("#{diffs}/#{l}.yaml", 'w') do |out|
      out.write(diff.to_yaml)
    end
  end

  if missing.size > 0
    pct = ((template.keys.size - (varstyle + missing).uniq.size) * 100) / template.keys.size
    pct = " (#{pct}%)"
  else
    pct = ''
  end

  columns = 2

  if missing.size > 0
    status = 'error'
  elsif obsolete.size > 0 || varstyle.size > 0
    status = 'warning'
  else
    status = 'success'
  end

  log "bq(#{status}). #{language}#{pct}\n\n"
  [[missing, 'Missing'], [obsolete, 'Obsolete'], [varstyle, 'Old-style variable substitution']].each {|cat|
    keys, title = *cat
    next if keys.size == 0

    log "*#{title}*\n\n"
    keys.sort!
    while keys.size > 0
      row = (keys.shift(columns) + ['', ''])[0..columns-1]
      log "|" + row.join("|") + "|\n"
    end

    log "\n"
  }
}

$logfile.close if $logfile
