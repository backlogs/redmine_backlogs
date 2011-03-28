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

  template.keys.each {|key|
    missing << key if ! lang[l][key]
  }
  
  pct = ((templates.keys.size - missing.keys.size) * 100) / templates.keys.size

  lang[l].keys.each {|key|
    if !template[key]
      obsolete << key
    elsif lang[l][key].include?('{{')
      varstyle << key
    end
  }

  if missing.size > 0 || obsolete.size > 0
    columns = 2
    if pct == 100
    log "bq(error). #{language}\n\n"
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
  else
    log "bq(success). #{language}\n\n"
  end
}


$logfile.close if $logfile
