require 'rubygems'
require 'prawn'
require 'prawn/measurement_extensions'
require 'net/http'

require 'yaml'
require 'uri/common'
require 'open-uri/cached'
require 'zlib'
require 'nokogiri'

class String
  def units_to_points
    return Float(self) if self =~/[0-9]$/

    m = self.match(/^([^a-z\s]+)\s*([a-z]+)$/)
    raise "No units found for #{self}" unless m

    value = Float(m[1])
    case m[2]
      when 'mm'
        return value * 2.8346457
        
      when 'pt'
        return value

      when 'in'
        return value * 72

      else
        raise "Unexpected unit specification for #{self}"
    end
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

      @top_margin = layout['top_margin'].units_to_points
      @vertical_pitch = layout['vertical_pitch'].units_to_points
      @height = layout['height'].units_to_points
  
      @left_margin = layout['left_margin'].units_to_points
      @horizontal_pitch = layout['horizontal_pitch'].units_to_points
      @width = layout['width'].units_to_points

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
      return true if (label['down'] > 1) && (label['height'].units_to_points > label['vertical_pitch'].units_to_points)
      return true if (label['across'] > 1) && (label['width'].units_to_points > label['horizontal_pitch'].units_to_points)
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

        doc = Nokogiri::XML(labels)
        doc.remove_namespaces!
  
        doc.xpath('Glabels-templates/Template').each { |specs|
          label = nil
  
          papersize = specs['size']
          papersize = 'Letter' if papersize == 'US-Letter'
  
          specs.xpath('Label-rectangle').each { |geom|
            margin = nil
            geom.xpath('Markup-margin').each { |m| margin = m['size'] }
            margin = "1mm" if margin.blank?
  
            geom.xpath('Layout').each { |layout|
              label = {
                'inner_margin' => margin,
                'across' => Integer(layout['nx']),
                'down' => Integer(layout['ny']),
                'top_margin' => layout['y0'],
                'height' => geom['height'],
                'horizontal_pitch' => layout['dx'],
                'left_margin' => layout['x0'],
                'width' => geom['width'],
                'vertical_pitch' => layout['dy'],
                'papersize' => papersize,
                'source' => 'glabel'
              }
            }
          }
  
          next if label.nil?
  
          key = "#{specs['brand']} #{specs['part']}"

          if LabelStock.malformed(label)
            puts "Skipping malformed label '#{key}' from #{filename}"
            malformed_labels[key] = label
          else
            LAYOUTS[key] = label if not LAYOUTS[key] or LAYOUTS[key]['source'] == 'glabel'
  
            specs.xpath('Alias').each { |also|
              key = "#{also['brand']} #{also['part']}"
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

  # put the mixins in a separate class, seems to interfere with prawn otherwise
  class Gravatar
    include GravatarHelper::PublicMethods
    include ERB::Util

    def initialize(email, size)
      # see conversion chart pt -> px @ http://sureshjain.wordpress.com/2007/07/06/53/
      @url = gravatar_url(email, :size => (size * 16) / 12)
    end

    def image
      begin
        return open(@url)
      rescue
        return nil
      end
    end

    attr_reader :url
  end

  class Template

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
      @template = { :x => bounds['width'].units_to_points, :y => bounds['height'].units_to_points}

      @card = label.xpath('//Objects')[0]
      @width = width
      @height = height
    end

    def box(b, scaled=true)
      return {
        :x => (b['x'].units_to_points / @template[:x]) * @width,
        :y => (1 - (b['y'].units_to_points / @template[:y])) * @height,
        :w => (b['w'].units_to_points / @template[:x]) * @width,
        :h => (b['h'].units_to_points / @template[:y]) * @height
      }
    end

    def style(b)
      s = b.xpath('Span')[0]
      style = [s['font_weight'] == "Bold" ? 'bold' : nil, s['font_italic'] == "True" ? 'italic' : nil].compact.join('_')
      style = 'normal' if style == ''
      return {
        :size => Integer(s['font_size']),
        :style => style.intern
      }
    end

    def line_width(obj)
      return obj['line_width'].units_to_points
    end

    def color(obj, prop)
      c = obj[prop]
      return nil if c =~ /00$/
      raise "Alpha channel not supported" unless c =~ /ff$/i
      return c[2, 6]
    end

    def line(l)
      return {
        :x1 => (l['x'].units_to_points / @template[:x]) * @width,
        :y1 => (1 - (l['y'].units_to_points / @template[:y])) * @height,
        :x2 => ((l['x'].units_to_points + l['dx'].units_to_points) / @template[:x]) * @width,
        :y2 => (1 - ((l['y'].units_to_points + l['dy'].units_to_points) / @template[:y])) * @height
      }
      return data
    end

    def render(x, y, pdf, data)
      default_stroke_color = pdf.stroke_color
      default_fill_color = pdf.fill_color

      pdf.bounding_box [x, y], :width => @width, :height => @height do
        @card.children.each {|obj|
          next if obj.text?

          case obj.name
            when 'Object-box'
              dim = box(obj)
              pdf.fill_color = color(obj, 'fill_color') || default_fill_color
              pdf.stroke_color = color(obj, 'line_color') || default_stroke_color
              pdf.line_width = line_width(obj)

              pdf.stroke {
                if color(obj, 'fill_color')
                  pdf.fill_rectangle [312,260], 180, 16 
                else
                  pdf.rectangle [dim[:x], dim[:y]], dim[:w], dim[:h]
                end
              }


            when 'Object-line'
              dim = line(obj)
              pdf.line_width = line_width(obj)
              pdf.stroke_color = color(obj, 'line_color') || default_stroke_color

              pdf.stroke {
                pdf.line([dim[:x1], dim[:y1]], [dim[:x2], dim[:y2]])
              }

            when 'Object-text'
              dim = box(obj)

              pdf.fill_color = color(obj.xpath('Span')[0], 'color') || default_fill_color

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

              content.strip!

              s = style(obj)
              pdf.font_size(s[:size]) do
                Prawn::Text::Box.new(content, {:overflow => :ellipses, :at => [dim[:x], dim[:y]], :document => pdf, :width => dim[:w], :height => dim[:h], :style => s[:style]}).render
              end

            when 'Object-image'
              if data['owner.email']
                dim = box(obj)

                img = Gravatar.new(data['owner.email'], (dim[:h] < dim[:w]) ? dim[:h] : dim[:w]).image
                pdf.image img, :at => [dim[:x], dim[:y]], :width => dim[:w] if img
              end

            else
              raise "Unsupported object '#{obj.name}'"
          end
        }
      end

      pdf.stroke_color = default_stroke_color
      pdf.fill_color = default_fill_color
    end
  end

  class Cards
    include Redmine::I18n

    def initialize(stories, with_tasks, lang)
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

      
      case Setting.plugin_redmine_backlogs[:taskboard_card_order]
        when 'tasks_follow_story'
          stories.each { |story| 
            add(story)

            if with_tasks
              story.descendants.each {|task|
                add(task)
              }
            end
          }

        when 'stories_then_tasks'
          stories.each { |story| 
            add(story)
          }

          if with_tasks
            @cards  = 0
            @pdf.start_new_page

            stories.each { |story| 
              story.descendants.each {|task|
                add(task)
              }
            }
          end

        else # 'story_follows_tasks'
          stories.each { |story| 
            if with_tasks
              story.descendants.each {|task|
                add(task)
              }
            end
  
            add(story)
          }
      end
    end
  
    attr_reader :pdf
  
    def add(issue)
      row = @cards % @label.down
      col = Integer(@cards / @label.down) % @label.across
      @cards += 1
  
      @pdf.start_new_page if row == 0 and col == 0 and @cards != 1
  
      x = @label.left_margin + (@label.horizontal_pitch * col)
      y = @label.paper_height - (@label.top_margin + (@label.vertical_pitch * row))

      data = {}
      if issue.is_task?
        data['story.position'] = issue.story.position ? issue.story.position : l(:label_not_prioritized)
        data['story.id'] = issue.story.id
        data['story.subject'] = issue.story.subject

        data['id'] = issue.id
        data['subject'] = issue.subject.to_s.strip
        data['description'] = issue.description.to_s.strip; data['description'] = data['subject'] if data['description'] == ''
        data['category'] = issue.category ? issue.category.name : ''
        data['hours.estimated'] = (issue.initial_estimate || '?').to_s + ' ' + l(:label_hours)
        data['position'] = issue.position ? issue.position : l(:label_not_prioritized)
        data['path'] = (issue.self_and_ancestors.reverse.collect{|i| "#{i.tracker.name} ##{i.id}"}.join(" : ")) + " (#{data['story.position']})"
        data['sprint.name'] = issue.fixed_version ? issue.fixed_version.name : I18n.t(:backlogs_product_backlog)
        data['owner'] = issue.assigned_to.blank? ? "" : "#{issue.assigned_to.firstname} #{issue.assigned_to.lastname}"
        data['owner.email'] = issue.assigned_to.blank? ? nil : issue.assigned_to.mail.to_s.downcase

        card = @task

      elsif issue.is_story?
        data['id'] = issue.id
        data['subject'] = issue.subject
        data['description'] = issue.description.to_s.strip; data['description'] = data['subject'] if data['description'] == ''
        data['category'] = issue.category ? issue.category.name : ''
        data['size'] = (issue.story_points ? "#{issue.story_points}" : '?') + ' ' + l(:label_points)
        data['position'] = issue.position ? issue.position : l(:label_not_prioritized)
        data['path'] = (issue.self_and_ancestors.reverse.collect{|i| "#{i.tracker.name} ##{i.id}"}.join(" : ")) + " (#{data['story.position']})"
        data['sprint.name'] = issue.fixed_version ? issue.fixed_version.name : I18n.t(:backlogs_product_backlog)
        data['owner'] = issue.assigned_to.blank? ? "" : "#{issue.assigned_to.firstname} #{issue.assigned_to.lastname}"
        data['owner.email'] = issue.assigned_to.blank? ? nil : issue.assigned_to.mail.to_s.downcase

        card = @story

      else
        raise "Unsupported card type '#{type}'"

      end

      data.keys.each {|d| data[d] = data[d].to_s }

      card.render(x, y, @pdf, data)
    end
  
  end
end
