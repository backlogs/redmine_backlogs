#!/usr/bin/env ruby

require 'yaml'

en = YAML::load_file('en.yml')['en']
old_en = YAML::load_file('old/en.yml')['en']

new_keys = {}
old_en.each_pair{|ko, vo|
  vo = vo.gsub(/\{\{([^}]+)\}\}/, '%{\1}')
  en.each_pair {|kn, vn|
    if vn == vo
      new_keys[ko] ||= []
      new_keys[ko] << kn
    end
  }
  puts "Missing #{ko}" unless new_keys[ko]
}

Dir.glob("*.yml").select{|f| !['en.yml', 'old-en.yml'].include?(f)}.each {|f|
  trans = YAML::load_file(f)
  lang = trans.keys[0]

  if ! f.match(/^#{lang}\.yml$/)
    puts "Malformed translation #{f}"
    next
  end

  puts lang

  new_trans = trans.dup
  new_keys.each_pair{|ko, kns|
    kns.each{|kn|
      new_trans[lang][kn] = trans[lang][ko].gsub(/\{\{([^}]+)\}\}/, '%{\1}') if trans[lang][ko]
    }
  }

  en.each_pair {|key, txt|
    next if new_trans[lang][key]
    puts "#{lang} #{key} #{new_trans[lang][key]}"
    new_trans[lang][key] = "[[#{txt}]]"
  }
  new_trans[lang].keys.each {|k|
    new_trans[lang].delete(k) unless en[k]
  }

  File.open( f, 'w' ) do |out|
    YAML.dump(new_trans, out)
  end
}
