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
    end

    include Enumerable

    def initialize(arrays = {})
      @data = nil
      add(arrays)
    end

    def add(arrays)
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

    def each(&block)
      @data.each {|cell| block.call(cell) }
    end

    def to_s
      return @data.collect{|s| s.to_s}.join("\n")
    end
  end
end
