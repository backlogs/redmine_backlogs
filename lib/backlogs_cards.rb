require 'rubygems'
require 'prawn'
require 'prawn/measurement_extensions'
require 'net/http'
require 'rexml/document'

require 'yaml'
require 'uri/common'
require 'open-uri/cached'
require 'zlib'
require 'nokogiri'
require 'ruby-units'

class String
  def to_points
    return Float(self) if self =~/[0-9]$/
    return self.to_unit.to('pt').scalar
  end
end

module BacklogsCards
  class LabelStock
    begin
      LAYOUTS = YAML::load_file(File.dirname(__FILE__) + '/labels.yaml')
      LAYOUTS.keys.each{|k| LAYOUTS[k]['name'] = k }
    rescue
      LAYOUTS = {}
    end

    def initialize
      raise "No label stock selected" unless LabelStock.selected_label
      layout = LabelStock.selected_label

      @top_margin = layout['top_margin'].to_points
      @vertical_pitch = layout['vertical_pitch'].to_points
      @height = layout['height'].to_points
  
      @left_margin = layout['left_margin'].to_points
      @horizontal_pitch = layout['horizontal_pitch'].to_points
      @width = layout['width'].to_points

      @across = Integer(layout['across'])
      @down = Integer(layout['down'])
  
      layout['papersize'].upcase!

      geom = Prawn::Document::PageGeometry::SIZES[layout['papersize']]
      raise "Paper size '#{label['papersize']}' not supported" if geom.nil?
  
      @paper_width = geom[0]
      @paper_height = geom[1]
      @paper_size = layout['papersize']
    end

    attr_reader :left_margin, :horizontal_pitch, :width
    attr_reader :top_margin, :vertical_pitch, :height
    attr_reader :across, :down
    attr_reader :paper_width, :paper_height, :paper_size

    def self.selected_label
      return nil unless Setting.plugin_redmine_backlogs[:card_spec]
      return LAYOUTS[Setting.plugin_redmine_backlogs[:card_spec]]
    end

    def self.malformed(label)
      return true if label['down'] > 1 && label['height'] > label['vertical_pitch']
      return true if label['across'] > 1 && label['width'] > label['horizontal_pitch']
      return false
    end
  
    def self.fetch_labels
      # clean up existing labels
      LAYOUTS.keys.each {|label|
        if LabelStock.malformed(LAYOUTS[label])
          LAYOUTS.delete(label)
          puts "Removing malformed label '#{label}'"
        end
      }

      malformed_labels = {}

      ['avery-iso-templates.xml', 'avery-other-templates.xml', 'avery-us-templates.xml', 'brother-other-templates.xml', 'dymo-other-templates.xml',
       'maco-us-templates.xml', 'misc-iso-templates.xml', 'misc-other-templates.xml', 'misc-us-templates.xml', 'pearl-iso-templates.xml',  
       'uline-us-templates.xml', 'worldlabel-us-templates.xml', 'zweckform-iso-templates.xml'].each {|filename|

        uri = URI.parse("http://git.gnome.org/browse/glabels/plain/templates/#{filename}")
        labels = nil

        if ! ENV['http_proxy'].blank?
          begin
            proxy = URI.parse(ENV['http_proxy'])
            if proxy.userinfo
              user, pass = proxy.userinfo.split(/:/)
            else
              user = pass = nil
            end
            labels = Net::HTTP::Proxy(proxy.host, proxy.port, user, pass).start(uri.host) {|http| http.get(uri.path)}.body
          rescue URI::Error => e
            puts "Setup proxy failed: #{e}"
            labels = nil
          end
        end

        begin
          labels = Net::HTTP.get_response(uri).body if labels.nil?
        rescue
          labels = nil
        end

        if labels.nil?
          puts "Could not fetch #{filename}"
          next
        end

        doc = REXML::Document.new(labels)
  
        doc.elements.each('Glabels-templates/Template') { |specs|
          label = nil
  
          papersize = specs.attributes['size']
          papersize = 'Letter' if papersize == 'US-Letter'
  
          specs.elements.each('Label-rectangle') { |geom|
            margin = nil
            geom.elements.each('Markup-margin') { |m| margin = m.attributes['size'] }
            margin = "1mm" if margin.blank?
  
            geom.elements.each('Layout') { |layout|
              label = {
                'inner_margin' => margin,
                'across' => Integer(layout.attributes['nx']),
                'down' => Integer(layout.attributes['ny']),
                'top_margin' => layout.attributes['y0'],
                'height' => geom.attributes['height'],
                'horizontal_pitch' => layout.attributes['dx'],
                'left_margin' => layout.attributes['x0'],
                'width' => geom.attributes['width'],
                'vertical_pitch' => layout.attributes['dy'],
                'papersize' => papersize,
                'source' => 'glabel'
              }
            }
          }
  
          next if label.nil?
  
          key = "#{specs.attributes['brand']} #{specs.attributes['part']}"

          if LabelStock.malformed(label)
            puts "Skipping malformed label '#{key}' from #{filename}"
            malformed_labels[key] = label
          else
            LAYOUTS[key] = label if not LAYOUTS[key] or LAYOUTS[key]['source'] == 'glabel'
  
            specs.elements.each('Alias') { |also|
              key = "#{also.attributes['brand']} #{also.attributes['part']}"
              LAYOUTS[key] = label.dup if not LAYOUTS[key] or LAYOUTS[key]['source'] == 'glabel'
            }
          end
        }
      }
  
      File.open(File.dirname(__FILE__) + '/labels.yaml', 'w') do |dump|
        YAML.dump(LAYOUTS, dump)
      end
      File.open(File.dirname(__FILE__) + '/labels-malformed.yaml', 'w') do |dump|
        YAML.dump(malformed_labels, dump)
      end

      if Setting.plugin_redmine_backlogs[:card_spec] && ! LabelStock.selected_label && LAYOUTS.size != 0
        # current label non-existant
        label = LAYOUTS.keys[0]
        puts "Non-existant label stock '#{Setting.plugin_redmine_backlogs[:card_spec]}' selected, replacing with random '#{label}'"
        s = Setting.plugin_redmine_backlogs
        s[:card_spec] = label
        Setting.plugin_redmine_backlogs = s
      end
    end
  end

  class Template
    include GravatarHelper::PublicMethods
    include ERB::Util

    def initialize(width, height, template)
      f = nil
      ['-default', ''].each {|postfix|
        t = File.dirname(__FILE__) + "/#{template}#{postfix}.glabels"
        f = t if File.exists?(t)
      }
      raise "No template for #{template}" unless f
      label = Nokogiri::XML(Zlib::GzipReader.open(f))
      label.remove_namespaces!

      bounds = label.xpath('//Template/Label-rectangle')[0]
      @template = { :x => bounds['width'].to_points, :y => bounds['height'].to_points}

      @card = label.xpath('//Objects')[0]
      @width = width
      @height = height
    end

    def box(b, scaled=true)
      return {
        :x => (b['x'].to_points / @template[:x]) * @width,
        :y => (1 - (b['y'].to_points / @template[:y])) * @height,
        :w => (b['w'].to_points / @template[:x]) * @width,
        :h => (b['h'].to_points / @template[:y]) * @height
      }
    end

    def style(b)
      s = b.xpath('Span')[0]
      return {
        :size => Integer(s['font_size']),
        :weight => s['font_weight'],
        :italic => (s['font_italic'] != "False")
      }
    end

    def line(l)
      return {
        :x1 => (l['x'].to_points / @template[:x]) * @width,
        :y1 => (1 - (l['y'].to_points / @template[:y])) * @height,
        :x2 => ((l['x'].to_points + l['dx'].to_points) / @template[:x]) * @width,
        :y2 => (1 - ((l['y'].to_points + l['dy'].to_points) / @template[:y])) * @height
      }
      return data
    end

    def render(x, y, pdf, data)
      pdf.bounding_box [x, y], :width => @width, :height => @height do
        @card.children.each {|obj|
          next if obj.text?

          case obj.name
            when 'Object-line'
              dim = line(obj)
              pdf.line([dim[:x1], dim[:y1]], [dim[:x2], dim[:y2]])

            when 'Object-text'
              dim = box(obj)
              content = ''
              
              obj.xpath('Span')[0].children.each {|t|
                if t.text?
                  content << t.text
                elsif t.name == 'Field'
                  f = data[t['name']]
                  raise "Unsupported card variable '#{t['name']}" unless f
                  content << f
                else
                  raise "Unsupported text object '#{t.name}'"
                end
              }

              s = style(obj)
              pdf.font_size(s[:size]) do
                options = {:overflow => :ellipses, :at => [dim[:x], dim[:y]], :document => pdf, :width => dim[:w], :height => dim[:h]}
                options[:style => :italic] if s[:italic]

                Prawn::Text::Box.new(content, options).render
              end

            when 'Object-image'
              if data['email']
                dim = box(obj)

                size = (dim[:h] < dim[:w]) ? dim[:h] : dim[:w]

                # see conversion chart pt -> px @ http://sureshjain.wordpress.com/2007/07/06/53/
                image_url = gravatar_url(data['email'], :size => (size * 16) / 12)
                image_obj = open(image_url)
                pdf.image image_obj, :at => [dim[:x], dim[:y]], :width => dim[:w]
              end

            else
              raise "Unsupported object '#{obj.name}'"
          end
        }
      end
    end
  end

  class Cards
    include Redmine::I18n

    def initialize(lang)
      set_language_if_valid lang

      @label = LabelStock.new
      @story = Template.new(@label.width, @label.height, 'story')
      @task = Template.new(@label.width, @label.height, 'task')
  
      @pdf = Prawn::Document.new(
        :page_layout => :portrait,
        :left_margin => 0,
        :right_margin => 0,
        :top_margin => 0,
        :bottom_margin => 0,
        :page_size => @label.paper_size)

      fontdir = File.dirname(__FILE__) + '/ttf'
      @pdf.font_families.update(
        "DejaVuSans" => {
          :bold         => "#{fontdir}/DejaVuSans-Bold.ttf",
          :italic       => "#{fontdir}/DejaVuSans-Oblique.ttf",
          :bold_italic  => "#{fontdir}/DejaVuSans-BoldOblique.ttf",
          :normal       => "#{fontdir}/DejaVuSans.ttf"
        }
      )
      @pdf.font "DejaVuSans"

      @cards = 0
    end
  
    attr_reader :pdf
  
    def card(issue, type)
      row = (@cards % @label.down) + 1
      col = ((@cards / @label.down) % @label.across) + 1
      @cards += 1
  
      @pdf.start_new_page if row == 1 and col == 1 and @cards != 1
  
      x = @label.left_margin + (@label.horizontal_pitch * (col - 1))
      y = @label.paper_height - (@label.top_margin + @label.vertical_pitch * (row - 1))

      data = {}
      case type
        when :task
          data['story.position'] = issue.story.position ? issue.story.position : l(:label_not_prioritized)
          data['story.id'] = issue.story.id
          data['story.subject'] = issue.story.subject

          data['task.id'] = issue.id
          data['task.subject'] = issue.subject
          data['task.description'] = issue.description || data['story.subject']
          data['task.category'] = issue.category ? issue.category.name : ''
          data['task.hours.estimated'] = (issue.estimated_hours ? "#{issue.estimated_hours}" : '?') + ' ' + l(:label_hours)
          data['task.hours.remaining'] = (issue.hours_remaining ? "#{issue.hours_remaining}" : '?') + ' ' + l(:label_hours)
          data['task.position'] = issue.position ? issue.position : l(:label_not_prioritized)
          data['task.path'] = (issue.self_and_ancestors.reverse.collect{|i| "#{i.tracker.name} ##{i.id}"}.join(" : ")) + " (#{data['story.position']})"
          data['sprint.name'] = issue.fixed_version ? issue.fixed_version.name : I18n.t(:backlogs_product_backlog)
          data['task.owner'] = issue.assigned_to.blank? ? "" : "#{issue.assigned_to.firstname} #{issue.assigned_to.lastname}"
          data['email'] = issue.assigned_to.blank? ? nil : issue.assigned_to.mail.to_s.downcase

          card = @task

        when :story
          data['story.id'] = issue.id
          data['story.subject'] = issue.subject
          data['story.description'] = issue.description || data['story.subject']
          data['story.category'] = issue.category ? issue.category.name : ''
          data['story.size'] = (issue.story_points ? "#{issue.story_points}" : '?') + ' ' + l(:label_points)
          data['story.position'] = issue.position ? issue.position : l(:label_not_prioritized)
          data['story.path'] = (issue.self_and_ancestors.reverse.collect{|i| "#{i.tracker.name} ##{i.id}"}.join(" : ")) + " (#{data['story.position']})"
          data['story.owner'] = issue.assigned_to.blank? ? "" : "#{issue.assigned_to.firstname} #{issue.assigned_to.lastname}"
          data['sprint.name'] = issue.fixed_version ? issue.fixed_version.name : I18n.t(:backlogs_product_backlog)
          data['email'] = issue.assigned_to.blank? ? nil : issue.assigned_to.mail.to_s.downcase

          card = @story

        else
          raise "Unsupported card type '#{type}'"
      end

      data.keys.each {|d| data[d] = data[d].to_s }

      card.render(x, y, @pdf, data)
    end
  
    def add(story, add_tasks = true)
      if add_tasks
        story.descendants.each {|task|
          card(task, :task)
        }
      end
  
      card(story, :story)
    end
  end
end
