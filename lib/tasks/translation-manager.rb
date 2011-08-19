#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'

def root
  r = ''
  File.expand_path('.', __FILE__).gsub(/\\/, '/').split('/').reject{|d| d == ''}.each {|d|
    r += "/#{d}"
    return r if File.directory?("#{r}/redmine_backlogs")
  }
  return nil
end

class Translation
  @@source = nil
  @@translations = {}
  @@keys = nil

  def initialize(source, options={})
    @strings = {}
    @missing = []
    @obsolete = []
    @varstyle = []
    @lang = nil
    @source = source

    options[:register] = true unless options.include?(:register)
    options[:register] = true if options[:source]

    strings = YAML::load_file(source)
    @lang = strings.keys[0]
    strings[@lang].each_pair{|k, v| self[k] = v }

    rmtrans = "#{root}/redmine/config/locales/#{File.basename(source)}"
    @name = YAML::load_file(rmtrans)[@lang]['general_lang_name']

    raise "Translation '#{@lang}' already registered" if options[:register] && @@translations[@lang]
    @@translations[@lang] = self if options[:register]

    raise "Source re-registered!" if @@source && options[:source]
    if options[:source]
      @@source = self
      @@keys = []

      File.open(@@source.source).each {|line|
        m = line.match(/^\s+[-_a-z0-9]+\s*:/)
        next unless m
        key = m[0].strip.gsub(/:$/, '').strip
        @@keys << key
      }
    end

    test
  end

  attr_reader :lang, :name, :strings, :source
  attr_reader :missing, :obsolete, :varstyle

  def [](k)
    return @strings[k]
  end

  def []=(k, v)
    @strings[k] = v
    test
  end

  def keys
    @strings.keys.sort
  end

  def test
    if self == @@source
      @@translations.values.each {|t|
        next if t == self
        t.test
      }
    elsif @@source
      @missing = (@@source.keys - self.keys) + @@source.keys.select{|k| self[k] && self[k] =~ /^\[\[.*\]\]$/}
      @obsolete = self.keys - @@source.keys
      @varstyle = @@source.keys.select{|k| self[k] && self[k].include?('{{') }
    else
      @missing = []
      @obsolete = []
      @varstyle = []
    end
  end

  def self.source
    @@source
  end

  def self.keys
    @@keys
  end

  def self.cmp(a, b)
    pa = @@keys.index(a)
    pb = @@keys.index(b)

    return (pa <=> pb) if pa && pb
    return pa if pa
    return pb if pb
    return a <=> b
  end

  def self.test
    @@source.test if @@source
  end

  def self.translations
    return @@translations
  end

  def to_yaml(opts = {})
    strings = {}
    @@keys.each {|k| strings[k] = @strings[k]}
    return {@lang => strings}.to_yaml(opts)
  end
end

class Translation
  @@source = nil
  @@translations = {}

  def initialize(source, options={})
    @strings = {}
    @missing = []
    @obsolete = []
    @varstyle = []
    @lang = nil
    @source = source

    options[:register] = true unless options.include?(:register)
    options[:register] = true if options[:source]

    load(source, options)

    raise "Translation '#{@lang}' already registered" if options[:register] && @@translations[@lang]
    @@translations[@lang] = self if options[:register]

    raise "Source re-registered!" if @@source && options[:source]
    if options[:source]
      @@source = self
      @key_order = {}

      File.open(Translation.source.source).each_with_index {|line, no|
        m = line.match(/^\s+[-_a-z0-9]+\s*:/)
        next unless m
        key = m[0].strip.gsub(/:$/, '').strip
        @key_order[key] = no
      }
    end

    test
  end

  attr_reader :lang, :name, :strings, :source, :key_order
  attr_reader :missing, :obsolete, :varstyle

  def load(source, options)
    @author = options[:author] if options[:author]

    case File.extname(source)
      when '.qts', '.ts'
        doc = nil
        File.open(source) do |f|
          doc = Nokogiri::XML(f)
        end

        lang = doc.at('//TS')['language']
        author = doc.at('//TS')['extra-rbl-author']
        @author = author if author

        doc.xpath('//message').each {|message|
          id = message['id']
          t = message.at('translation')
          next if t['type'] == 'unfinished'
          self[id] = t.text
        }

      when '.yaml', '.yml'
        strings = YAML::load_file(source)
        lang = strings.keys[0]
        strings[lang].each_pair{|k, v| self[k] = v }

      else
        raise "Unsupported translation format '#{source}'"
    end

    raise "Cannot load '#{lang}' over '#{@lang}'" if @lang && @lang != lang
    @lang = lang

    rmtrans = File.expand_path(File.join('..', '..', '..', 'redmine', 'config', 'locales'), File.dirname(__FILE__))
    rmtrans = File.join(rmtrans, "#{File.basename(source, File.extname(source))}.yml")
    @name = YAML::load_file(rmtrans)[@lang]['general_lang_name']
  end

  def [](k)
    return @strings[k]
  end

  def []=(k, v)
    @strings[k] = v
    test
  end

  def keys
    @strings.keys.sort
  end

  def test
    if self == @@source
      @@translations.values.each {|t|
        next if t == self
        t.test
      }
    elsif @@source
      @missing = (@@source.keys - self.keys) + @@source.keys.select{|k| self[k] && self[k] =~ /^\[\[.*\]\]$/}
      @obsolete = self.keys - @@source.keys
      @varstyle = @@source.keys.select{|k| self[k] && self[k].include?('{{') }
    else
      @missing = []
      @obsolete = []
      @varstyle = []
    end
  end

  def self.source
    @@source
  end

  def self.test
    @@source.test if @@source
  end

  def self.translations
    return @@translations
  end

  def to_yaml(opts = {})
    if @@source
      strings = {}
      @@source.keys.each {|k| strings[k] = @strings[k]}
    else
      strings = @strings
    end
    return {@lang => strings}.to_yaml(opts)
  end
  
  def to_qts
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.doc.create_internal_subset('TS', nil, "qtlinguist.dtd")
      xml.TS({'sourcelanguage' => @@source.lang.gsub('-', '_'), 'language' => @lang.gsub('-', '_')}.merge(@author ? {'extra-rbl-author' => @author} : {})) {
        xml.context_ {
          xml.name('Redmine Backlogs')
          @@source.strings.each_pair {|id, str|
            xml.message('id' => id) {
              xml.source(str)

              attrs = {}
              attrs['type'] = 'unfinished' if @varstyle.include?(id) || @missing.include?(id)
              xml.translation(@strings[id] || '', attrs)

              xml.translatorcomment('Please replace {{...}} variables with %{...} variables') if @varstyle.include?(id)
            }
          }
          #@obsolete.each {|id|
          #  xml.message {
          #    xml.source("Obsolete key '#{id}' -- use for reference, or delete")
          #    xml.translation(@strings[id], 'type' => 'obsolete')
          #    xml.translatorcomment('Obsolete -- only kept for reference')
          #  }
          #}
        }
      }
    end

    return builder.to_xml
  end

  def to_xliff
    builder = Nokogiri::XML::Builder.new do |xml|
      xml.xliff(:version => '1.2', 'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance", 'xsi:schemaLocation' => 'urn:oasis:names:tc:xliff:document:1.2 xliff-core-1.2-transitional.xsd') {
        xml.file(:original => 'Redmine Backlogs', "source-language" => @@source.lang, "target-language" => @lang, 'datatype' =>'plaintext') {
          xml.header
          xml.body {
            @@source.strings.each_pair {|id, str|
              xml.send(:"trans-unit", :id => id) {
                attr = {'xml:lang' => @lang}
                if @missing.include?(id)
                  attr['state'] = 'needs-translation'
                elsif @varstyle.include?(id)
                  attr['state'] = 'needs-adaptation'
                else
                  attr['state'] = 'final'
                end

                xml.source(str, 'xml:lang' => 'en')

                xml.target(@strings[id] || str, attr)

                xml.note('Needs translation') if @missing.include?(id)
                xml.note('Uses {{...}} variable substitution, please change to %{...}') if @varstyle.include?(id)
              }
            }
            #@obsolete.each {|id|
            #  xml.send(:"trans-unit", :id => id) {
            #    xml.source("Obsolete key '#{id}' -- use for reference, or delete", 'xml:lang' => 'en')
            #    xml.target(@strings[id], 'xml:lang' => @lang, 'state' => 'needs-review-translation')
            #    xml.note('Obsolete -- only kept for reference')
            #  }
            #}
          }
        }
      }
     end

     return builder.to_xml
  end

end

class TranslationManager
  @@configfile = File.join(File.dirname(__FILE__), File.basename(__FILE__, File.extname(__FILE__))) + '.rc'
  @@config = File.exists?(@@configfile) ? YAML::load(File.open(@@configfile)) : {}

  def initialize
    @webdir = File.join(root, 'www.redminebacklogs.net')
    @translations = File.join(root, 'redmine_backlogs', 'config', 'locales')

    raise "Website not found at '#{@webdir}'" unless File.directory?(@webdir)
    raise "Translations not found at '#{@translations}'" unless File.directory?(@translations)

    @webpage = File.join(@webdir, '_posts', 'en', '1992-01-01-translations.textile')

    Dir.chdir(@translations)
    Dir.glob(File.join(@translations, "*.yml")).sort.each {|trans|
      Translation.new(trans, :source => (File.basename(trans) == 'en.yml'))
    }

    raise "Source translation 'en' not found" unless Translation.source
  end

  def save
    Translation.translations.values.each {|t|
      File.open(File.join(@translations, "#{t.lang}.yml"), 'w') do |out|
        out.write(t.to_yaml)
      end
    }
    Dir.chdir(@translations)
    `git add .`
    `git commit -m "Translation updates"`
    #`git push`

    make_page
    Dir.chdir(File.dirname(@webpage))
    `git add #{File.basename(@webpage)}`
    `git commit -m "Translation updates"`
    #`git push`
  end

  def make_page
    header = File.open(@webpage).read
    header, rest = header.split(/bq\(success\)\. /, 2)
    raise "'#{@webpage}' is not a proper template" if header.size == 0 || rest.size == 0
    header = header.strip + "\n\n"

    File.open(@webpage, 'w') do |page|
      page.write(header)
      page.write("\nbq(success). #{Translation.source.name}\n\nserves as a base for all other translations\n\n")

      Translation.translations.values.reject{|t| t.lang == Translation.source.lang}.sort{|a, b| a.name <=> b.name }.each {|t|
        if t.missing.size > 0 || t.varstyle.size > 0
          pct = ((Translation.source.keys.size - (t.varstyle + t.missing).uniq.size) * 100) / Translation.source.keys.size
          pct = "(#{pct}%)"
        else
          pct = ''
        end

        columns = 2

        if t.missing.size > 0
          status = 'error'
        elsif t.obsolete.size > 0 || t.varstyle.size > 0
          status = 'warning'
        else
          status = 'success'
        end

        page.write("bq(#{status}). #{t.name} #{pct}\n\n")

        [[:missing, 'Missing'], [:obsolete, 'Obsolete'], [:varstyle, 'Old-style variable substitution']].each {|cat|
          keys, title = *cat
          keys = t.send(keys)
          next if keys.size == 0

          page.write("*#{title}*\n\n")
          keys.sort!
          while keys.size > 0
            row = (keys.shift(columns) + ['', ''])[0..columns-1]
            page.write("|" + row.join("|") + "|\n")
          end

          page.write("\n")
        }
      }
    end
  end
end

class Hash
  # sorted keys for cleaner diffs in git
  def to_yaml(opts = {})
    YAML::quick_emit(object_id, opts) do |out|
      out.map(taguri, to_yaml_style) do |map|
        sort{|a, b| Translation.cmp(a, b) }.each do |k, v|
          map.add(k, v)
        end
      end
    end
  end
end


tm = TranslationManager.new
tm.save
