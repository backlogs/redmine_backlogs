#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'cmess/guess_encoding'
require 'iconv'
require 'nokogiri'
require 'fileutils'

class TranslationManager
  def initialize
    @webdir = File.expand_path(File.join('..', '..', '..', 'www.redminebacklogs.net'), File.dirname(__FILE__))
    @rmtrans = File.expand_path(File.join('..', '..', '..', 'redmine', 'config', 'locales'), File.dirname(__FILE__))
    @rbltrans = File.expand_path(File.join('..', '..', 'config', 'locales'), File.dirname(__FILE__))

    raise "Website not found at '#{@webdir}'" unless File.directory?(@webdir)
    raise "Redmine translations not found at '#{@rmtrans}'" unless File.directory?(@rmtrans)
    raise "Backlogs translations not found at '#{@rbltrans}'" unless File.directory?(@rbltrans)

    @webpage = File.join(@webdir, '_posts', 'en', '1992-01-01-translations.textile')

    @translation = {}
    @status = {}
    @name = {}

    Dir.glob(File.join(@rbltrans, "*.yml")).sort.each {|trans|
      strings = YAML::load_file(trans)
      lang = strings.keys[0]

      @translation[lang] = strings[lang]

      rmsource = File.join(@rmtrans, File.basename(trans))
      charset = CMess::GuessEncoding::Automatic.guess(File.open(rmsource).read)
      @name[lang] = Iconv.iconv('UTF-8', charset, YAML::load_file(rmsource)[lang]['general_lang_name'])
      raise "Cannot find name for '#{lang}'" unless @name[lang]
    }

    raise "Source translation 'en' not found" unless @translation['en']

    @translation.keys.each {|l|
      @status[l] = {
        :missing => (@translation['en'].keys - @translation[l].keys) + @translation['en'].keys.select{|k| @translation[l][k] && @translation[l][k] =~ /^\[\[.*\]\]$/},
        :obsolete => @translation[l].keys - @translation['en'].keys,
        :varstyle => @translation['en'].keys.select{|k| @translation[l][k] && @translation[l][k].include?('{{') }
      }
    }
  end

  def make_page(type)
    header = File.open(@webpage).read
    header, rest = header.split(/bq\(success\)\. /, 2)
    raise "'#{@webpage}' is not a proper template" if header.size == 0 || rest.size == 0
    header = header.strip + "\n\n"

    File.open(@webpage, 'w') do |page|
      page.write(header)
      page.write("\nbq(success). \"#{@name['en']}\":#{url('en', type)}\n\nserves as a base for all other translations\n\n")

      @translation.keys.reject{|lang| lang == 'en'}.sort{|a, b| @name[a] <=> @name[b] }.each {|l|
        if @status[l][:missing].size > 0 || @status[l][:varstyle].size > 0
          pct = ((@translation['en'].keys.size - (@status[l][:varstyle] + @status[l][:missing]).uniq.size) * 100) / @translation['en'].keys.size
          pct = "(#{pct}%)"
        else
          pct = ''
        end

        columns = 2

        if @status[l][:missing].size > 0
          status = 'error'
        elsif @status[l][:obsolete].size > 0 || @status[l][:varstyle].size > 0
          status = 'warning'
        else
          status = 'success'
        end

        page.write("bq(#{status}). \"#{@name[l]}\":#{url(l, type)} #{pct}\n\n")

        [[:missing, 'Missing'], [:obsolete, 'Obsolete'], [:varstyle, 'Old-style variable substitution']].each {|cat|
          keys, title = *cat
          keys = @status[l][keys]
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

  def xliff
    @translation.each_pair {|l, strings|
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.xliff(:version => '1.2') {
          xml.file(:original => 'Redmine Backlogs', "source-language" => 'en', "target-language" => l.gsub('_', '-'))
          xml.header
          xml.body {
            @translation['en'].each_pair {|id, str|
              xml.send(:"trans-unit", :id => id) {
                if l == 'en'
                  state='final'
                elsif @status[l][:missing].include?(id)
                  state = 'needs-translation'
                elsif @status[l][:varstyle].include?(id)
                  state = 'needs-adaptation'
                else
                  state = 'final'
                end

                xml.source(str, 'xml:lang' => 'en-US')

                if state
                  xml.target(@translation[l][id] || str, 'xml:lang' => l.gsub('_', '-'), 'state' => state)
                else
                  xml.target(@translation[l][id] || str, 'xml:lang' => l.gsub('_', '-'))
                end

                xml.note('Needs translation') if @status[l][:missing].include?(id)
                xml.note('Uses {{...}} variable substitution, please change to %{...}') if @status[l][:varstyle].include?(id)
              }
            }
            @status[l][:obsolete].each {|id|
              xml.send(:"trans-unit", :id => id) {
                xml.source("Obsolete key '#{id}' -- use for reference, or delete", 'xml:lang' => 'en-US')
                xml.target(@translation[l][id], 'xml:lang' => l.gsub('_', '-'), 'state' => 'needs-review-translation')
                xml.note('Obsolete -- only kept for reference')
              }
            }
          }
        }
      end

      File.open(File.join(@webdir, 'translations', "#{l}.xliff"), 'w') do |xliff|
        xliff.write(builder.to_xml)
      end
    }
  end

  def qts
    FileUtils.mkdir_p(File.join(@webdir, 'translations'))

    @translation.each_pair {|l, strings|
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.doc.create_internal_subset('TS', nil, "qtlinguist.dtd")
        xml.TS('sourcelanguage' => 'en', 'language' => l) {
          xml.context_ {
            xml.name('Redmine Backlogs')
            @translation['en'].each_pair {|id, str|
              xml.message('id' => id) {
                xml.source(str)
  
                attrs = {}
                attrs['type'] = 'unfinished' if @status[l][:varstyle].include?(id) || @status[l][:missing].include?(id)
                xml.translation(@translation[l][id] || str, attrs)
  
                xml.translatorcomment('Please replace {{...}} variables with %{...} variables') if @status[l][:varstyle].include?(id)
              }
            }
            @status[l][:obsolete].each {|id|
              xml.message {
                xml.source("Obsolete key '#{id}' -- use for reference, or delete")
                xml.translation(@translation[l][id], 'type' => 'obsolete')
                xml.translatorcomment('Obsolete -- only kept for reference')
              }
            }
          }
        }
      end

      File.open(File.join(@webdir, 'translations', "#{l}.ts"), 'w') do |ts|
        ts.write(builder.to_xml)
      end
    }
  end

  def android
    @translation.each_pair {|l, strings|
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.resources {
          @translation['en'].each_pair {|id, str|
            str = @translation[l][id] || str
            str = "!varstyle #{str}" if @status[l][:varstyle].include?(id)
            str = "!needs-translation #{str}" if @status[l][:missing].include?(id)

            xml.string(str, 'name' => id)
          }
        }
      end

      tgt = File.join(@webdir, 'translations', 'res', "values-#{l}", 'strings.xml')
      FileUtils.mkdir_p(File.dirname(tgt))
      File.open(tgt, 'w') do |l|
        l.write(builder.to_xml)
      end
    }
  end

  def url(l, type)
    u = "http://www.redminebacklogs.net/translations/"

    case type
      when :xliff
        return "#{u}#{l}.xliff"
      when :android
        return "#{u}res/values-#{l}/strings.xml"
      when :qts
        return "#{u}#{l}.ts"
      else
        raise "Unsupported translation type #{type.inspect}"
    end
  end

  def save_site
    dirty = false
    @status.values.each{|s|
      s.each{|e|
        dirty = true
        break
      }
    }

    return unless dirty

    Dir.chdir(@webdir)
    `git add .`
    `git commit -m "Translation updates"`
    `git push`
  end
end

tm = TranslationManager.new
#tm.xliff
#tm.android
tm.qts
tm.make_page(:qts)
#tm.save_site
