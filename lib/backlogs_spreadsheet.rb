require 'rubygems'
require 'nokogiri'
require 'time'

module BacklogsSpreadsheet
  class WorkSheet
    def initialize(workbook, name)
      @workbook = workbook
      @name = name

      @cells = {}
      @row = 0
      @col = 0
    end

    def <<(data)
      if data.is_a?(Array)
        @row += 1 if @row != 0 && @col != 0
        @col = 0
        data.each {|c| self[@row, @col] = c }
      else
        self[@row, @col] = data
      end
    end

    def newline
      @col = 0
      @row += 1
    end

    def [](row, col)
      return @cells[row][col]
    end

    def []=(row, col, c)
      if c
        @cells[row] ||= {}
        @cells[row][col] = c
      else
        @cells[row].delete(col) if @cells[row]
        @cells.delete(row) if @cells[row] && @cells[row].size == 0
      end
      @row = row
      @col = col + 1
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

    def load(rows)
      rows.each{|row|
        self << row
      }
    end

    attr_accessor :name

    def to_xml(xml)
      rows, cols = *dimensions
      xml.Worksheet('ss:Name' => @name) {
        xml.Table('ss:ExpandedColumnCount' => cols.to_s, 'ss:ExpandedRowCount' => rows.to_s, 'x:FullColumns' => "1", 'x:FullRows' => "1") {
          @cells.keys.sort.each {|row|
            xml.Row('ss:Index' => (row+1).to_s) {
              @cells[row].keys.sort.each {|col|
                xml.Cell('ss:Index' => (col+1).to_s) {
                  v = @cells[row][col]
                  if v.is_a?(Float) || v.is_a?(Integer)
                    t = 'Number'
                  elsif v.is_a?(Date) || v.is_a?(DateTime) || v.is_a?(Time)
                    t = 'DateTime'
                  else
                    t = 'String'
                  end
                  xml.Data(v.to_s, 'ss:Type' => t)
                }
              }
            }
          }
        }
      }
    end
  end

  class WorkBook
    def initialize
      @worksheets = []
    end

    def [](i)
      return @worksheets[i] if i.is_a?(Integer)

      raise "Index can only be a number or a name" unless i.is_a?(String)

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

    attr_accessor :worksheets

    def load(data)
      if data.is_a?(String)
        data = File.open(data)
        close = true
      else
        close = false
      end

      doc = Nokogiri::XML(data)
      doc.remove_namespaces!

      doc.xpath('//Worksheet').each {|ws|
        _ws = self[ws['name']]

        ws.xpath('Table/Row').each_with_index {|row, i|
          rownum = Integer(row['Index'] || (i+1)) - 1
          row.xpath('Cell').each_with_index {|cell, i|
            colnum = Integer(row['Index'] || (i+1)) - 1
            v = cell.at('Data')

            case v['Type']
              when 'Number'
                v = (v.text =~ /^[0-9]+(\.0+)?$/ ? Integer(v.text) : Float(v.text))
              when 'String', nil
                v = v.text
              when 'DateTime'
                v = Time.parse(v.text)
              else
                raise "Unsupported cell format '#{data['Type']}'"
            end

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
          @worksheets.each{ |w| w.to_xml(xml) }
        }
      end

      builder.doc.root.add_previous_sibling Nokogiri::XML::ProcessingInstruction.new(builder.doc, "mso-application", 'progid="Excel.Sheet"')
      return builder.to_xml
    end
  end
end
