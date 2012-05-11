module Backlogs
  class MergedArray
    class FlexObject < Hash
      def initialize(data = {})
        super

        data.each_pair {|k, v|
          raise "#{k} is not a symbol" unless k.is_a?(Symbol)
          self[k] = v
        }
      end

      def [](key)
        raise "Key '#{key}' does not exist" unless self.include?(key)
        raise "Key '#{key}' is not a symbol" unless key.is_a?(Symbol)
        return super(key)
      end

      def []=(key, value)
        raise "Key '#{key}' is not a symbol" unless key.is_a?(Symbol)
        super(key, value)
      end

      def method_missing(method_sym, *arguments, &block)
        if method_sym.to_s =~ /=$/ && arguments.size == 1
          self[method_sym.to_s.gsub(/=$/, '').intern] = arguments[0]
        elsif self.include?(method_sym)
          return self[method_sym]
        else
          super(method_sym, *arguments, &block)
        end
      end

      def nilify
        keys.each{|k| self[k] = nil}
      end
    end

    def initialize(arrays = {})
      @data = nil
      merge(arrays)
    end

    def merge(arrays)
      arrays.each_pair do |name, data|
        raise "#{name} is not a symbol" unless name.is_a?(Symbol)
        raise "#{name} is not a array" unless data.is_a?(Array)

        if @data
          raise "#{name} must have length of #{@data.size}, actual size #{data.size}" unless @data == [] || data.size == @data.size
          @data.zip(data).each {|cell, v| cell[name] = v }
        else
          @data = data.collect{|v| FlexObject.new(name => v) }
        end
      end
    end

    def add(arrays)
      return unless arrays
      arrays.each_pair do |name, data|
        next if data.nil?
        raise "#{name} is not a symbol" unless name.is_a?(Symbol)
        raise "#{name} is not a array" unless data.is_a?(Array)
        raise "#{name} not initialized" unless @data && @data.size > 0 && @data[0].include?(name)
        raise "data series '#{name}' is too long (got #{data.size}, maximum accepted #{@data.size})" if data.size > @data.size

        data.each_with_index{|d, i|
          @data[i][name] += d if d
        }
      end
    end

    def [](i)
      return @data[i]
    end

    def each(&block)
      @data.each {|cell| block.call(cell) }
    end
    def each_with_index(&block)
      @data.each_with_index {|cell, index| block.call(cell, index) }
    end

    def collect(&block)
      @data.collect {|cell| block.call(cell) }
    end

    def series(name)
      @data.collect{|cell| cell[name]}
    end

    def to_s
      return @data.to_s
    end
    def inspect
      return @data.collect{|d| d.inspect}.join("\n")
    end
  end
end
