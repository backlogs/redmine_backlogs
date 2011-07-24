require 'rubygems'
require 'nokogiri'
require 'time'
require 'date'
require 'delegate'

module BacklogsSpreadsheet
  class StyleManager
    def initialize
      @styles = []
    end

    def add(s)
      ns = Style.new(s)
      @styles.each {|s|
        next unless s == ns
        return s if s.id == ns.id || ns.auto
      }
      @styles << ns
      return ns
    end

    def to_xml(xml)
      xml.Styles { @styles.each{|s| s.to_xml(xml) }}
    end
  end

  class Style
    def initialize(options)
      # make a deep clone to avoid other people messing with our data
      options = Marshal.load( Marshal.dump( options ) )

      @id = options.delete(:id)
      @auto = false
      unless @id
        @auto = true
        @id = "s#{self.object_id.abs.to_s}"
      end

      if options[:font] && options[:font].size > 0
        @font = {
          'ss:FontName' => options[:font][:name] || 'Calibri',
          'x:Family' => options[:font][:name] || 'Swiss',
          'ss:Size' => options[:font][:size] || 11,
          'ss:Color' => options[:font][:color] || '#000000',
        }
        @font['ss:Bold'] = '1' if options[:font][:bold]
        @font['ss:Italic'] = '1' if options[:font][:italic]
      end

      @numberformat = options[:numberformat]
    end

    attr_reader :id, :auto, :font, :numberformat

    def ==(other)
      return font == other.font && numberformat == other.numberformat
    end

    def to_xml(xml)
      xml.Style('ss:ID' => @id) {
        xml.Font(@font) if @font
        xml.NumberFormat(@numberformat) if @numberformat
      }
    end
  end

  module Cell
    def initialize(value, worksheet, options={})
      super(value)

      @worksheet = worksheet

      style = default_style.merge(options[:style] || {})
      @style = worksheet.workbook.stylemanager.add(style) if style.size > 0
      @comment = options[:comment]
    end

    def default_style
      return {}
    end

    attr_accessor :style
    attr_accessor :comment

    def to_xml(xml, col)
      cellopts = {'ss:Index' => (col+1).to_s}
      cellopts['ss:StyleID'] = @style.id if @style
      xml.Cell(cellopts) {
        xml.Data(self.to_s, 'ss:Type' => celltype)
        if @comment
          xml.Comment {
            xml.send(:"ss:Data", @comment, 'xmlns' => "http://www.w3.org/TR/REC-html40") {
            }
          }
        end
      }
    end

    def celltype
      return self.class.name.gsub(/^.*::/, '').gsub(/Cell$/, '')
    end
  end

  class NumberCell < DelegateClass(Float)
    include Cell

    def is_a?(x)
      return (x == NumberCell) || Float.ancestors.include?(x)
    end
  end

  class StringCell < String
    include Cell
  end

  #class DateTimeCell < DateTime # < DelegateClass(Time)
  class DateTimeCell < DelegateClass(DateTime)
    include Cell

    def is_a?(x)
      return (x == DateTimeCell) || DateTime.ancestors.include?(x)
    end

    def to_s
      return self.strftime('%FT%T.%L')
    end

    def default_style
      return {:numberformat => {'ss:Format' => 'Short Date'}} if self.hour == 0 && self.min == 0 && self.sec == 0
      return {:numberformat => {'ss:Format' => 'General Date'}}
    end
  end

  class WorkSheet
    def initialize(workbook, name)
      @workbook = workbook
      @name = name

      @cells = {}
      @row = 0
      @col = 0
    end

    attr_reader :workbook

    def <<(data)
      if data.is_a?(Array)
        @row += 1 if @col != 0
        @col = 0
        data.each {|c| self[@row, @col] = c }
        @row += 1
        @col = 0
      else
        self[@row, @col] = data
      end
    end

    def newline
      @col = 0
      @row += 1
    end

    def [](row, col)
      return nil unless @cells[row]
      return @cells[row][col]
    end

    def []=(row, col, c)
      @row = row
      @col = col + 1

      if c
        if c.class.included_modules.include?(BacklogsSpreadsheet::Cell)
          c = c.clone
        else
          options = {}
          if c.is_a?(Hash)
            options = c.clone
            c = options.delete(:value)
          end

          c = DateTime.civil(c.year, c.month, c.mday) if c.is_a?(Date)

          if c.is_a?(Time)
            seconds = c.sec + Rational(c.usec, 10**6)
            offset = Rational(c.utc_offset, 60 * 60 * 24)
            c = DateTime.new(c.year, c.month, c.day, c.hour, c.min, seconds, offset)
          end

          if c.is_a?(Float) || c.is_a?(Integer)
            c = NumberCell.new(c, self, options)
          elsif c.is_a?(String)
            c = StringCell.new(c, self, options)
          elsif c.is_a?(DateTime)
            c = DateTimeCell.new(c, self, options)
          else
            raise "Unsupported cell type '#{c.class}'"
          end
        end

        @cells[row] ||= {}
        @cells[row][col] = c

      else
        @cells[row].delete(col) if @cells[row]
        @cells.delete(row) if @cells[row] && @cells[row].size == 0

      end
    end

    def dimensions
      return [@cells.keys.max + 1, @cells.values.collect{|r| r.keys }.flatten.max + 1]
    end

    def rows
      r, c = *dimensions
      data = [ [nil] * c ] * r
      @cells.each_pair {|r, v|
        v.each_pair {|c, v|
          data[r][c] = v
        }
      }
      return data
    end

    attr_accessor :name

    def to_xml(xml)
      rows, cols = *dimensions
      xml.Worksheet('ss:Name' => @name) {
        xml.Table('ss:ExpandedColumnCount' => cols.to_s, 'ss:ExpandedRowCount' => rows.to_s, 'x:FullColumns' => "1", 'x:FullRows' => "1") {
          @cells.keys.sort.each {|row|
            xml.Row('ss:Index' => (row+1).to_s) {
              @cells[row].keys.sort.each {|col|
                @cells[row][col].to_xml(xml, col)
              }
            }
          }
        }
      }
    end
  end

  class WorkBook
    def initialize(file = nil)
      @worksheets = []
      @stylemanager = StyleManager.new
      self.load(file) if file
    end

    attr_reader :stylemanager, :worksheets

    def [](i)
      return @worksheets[i] if i.is_a?(Integer)

      raise "Index can only be a number or a name, not a #{i.class.name}" unless i.is_a?(String)

      i.strip!

      w = @worksheets.select{|w| w.name.downcase == i.downcase}
      return w[0] if w.size > 1

      w = BacklogsSpreadsheet::WorkSheet.new(self, i)
      @worksheets << w
      return w
    end

    def sheetnames
      return @worksheets.collect{|w| w.name }
    end

    def load(data)
      @worksheets = []
      @stylemanager = StyleManager.new

      if data.is_a?(String)
        data = File.open(data)
        close = true
      else
        close = false
      end

      doc = Nokogiri::XML(data)
      doc.remove_namespaces!

      doc.xpath('//Worksheet').each {|ws|
        _ws = self[ws['Name']]

        ws.xpath('Table/Row').each_with_index {|row, i|
          rownum = Integer(row['Index'] || (i+1)) - 1
          row.xpath('Cell').each_with_index {|cell, i|
            colnum = Integer(cell['Index'] || (i+1)) - 1
            v = cell.at('Data')

            raise "No cell data" unless v

            case v['Type']
              when 'Number'
                v = (v.text =~ /^[0-9]+(\.0+)?$/ ? Integer(v.text.gsub(/\.0+/, '')) : Float(v.text))
              when 'String', nil
                v = v.text
              when 'DateTime'
                v = Time.parse(v.text)
              else
                raise "Unsupported cell format '#{data['Type']}'"
            end

            c = cell.at('Comment//Data')
            v = {:value => v, :comment => c.text} if c

            _ws[rownum, colnum] = v
          }
        }
      }

      data.close if close
    end

    def to_xml
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.Workbook('xmlns' => "urn:schemas-microsoft-com:office:spreadsheet",
                     'xmlns:o' => "urn:schemas-microsoft-com:office:office",
                     'xmlns:x' => "urn:schemas-microsoft-com:office:excel",
                     'xmlns:ss' => "urn:schemas-microsoft-com:office:spreadsheet",
                     'xmlns:html' => "http://www.w3.org/TR/REC-html40") {
          xml.ExcelWorkbook('xmlns' => "urn:schemas-microsoft-com:office:excel")
          @stylemanager.to_xml(xml)
          @worksheets.each{ |w| w.to_xml(xml) }
        }
      end

      builder.doc.root.add_previous_sibling Nokogiri::XML::ProcessingInstruction.new(builder.doc, "mso-application", 'progid="Excel.Sheet"')
      return builder.to_xml
    end
  end
end
