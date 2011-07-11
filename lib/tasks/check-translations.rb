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

log <<EOF
---
title: Translations
layout: default
categories: en
---
h1. Translations

<script>
    $(document).ready(function() {
        $('a.show-instructions').attr('href', '#');
        $('.instructions').hide();

        $('a.show-instructions').click(function() {
          $('.instructions').toggle();
        });
    });
</script>

*Want to help out with translating Backlogs? Excellent! Click "(show-instructions)here":http://www.example.com for more info!*

 <div class="instructions">
Create an account at "GitHub":http://www.github.com if you don't have one yet. "Fork":https://github.com/relaxdiego/redmine_backlogs/fork the "Backlogs":http://github.com/relaxdiego/redmine_backlogs repository, check it out to your local PC, and change the translation files in config/locales. Check it into your clone, and then issue a "pull request":https://github.com/relaxdiego/redmine_backlogs/pull/new/master, and I'll be able to fetch your changes. The changes will automatically be attributed to you.

Alternately, but this won't get you attribution, "download":http://github.com/relaxdiego/redmine_backlogs/tree/master/config/locales the raw translation file, change them as you wish, and then post them in a "gist":https://gist.github.com/, and add an issue in our "issue tracker":https://github.com/relaxdiego/redmine_backlogs/issue with a link to your gist.

The messages below mean the following:

| *Missing* | the key is not present in the translation. |
| *Obsolete* | the key is present but no longer in use, so it should be removed. |
| *Old-style variable substitution* | the translation uses { { keyword } } instead of %{keyword}. This works for now, but redmine is in the process of phasing it out. |

 </div>

bq(success). US English

serves as a base for all other translations

EOF

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

if File.directory? webdir
  Dir.chdir(webdir)
  `git add .`
  `git commit -m "Translation updates"`
  `git push`
end
