module Backlogs
  class MergedArray
    class FlexObject
      def initialize(key, value)
        raise "#{key} is not a symbol" unless key.is_a?(Symbol)
        @data = {key => value}
      end

      def method_missing(method_sym, *arguments, &block)
        if method_sym.to_s =~ /=$/ && arguments.size == 1
          @data[method_sym.to_s.gsub(/=$/, '').intern] = arguments[0]
        elsif @data.include?(method_sym)
          return @data[method_sym]
        else
          super
        end
      end

      def to_s
        return @data.inspect
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
          @data.zip(data).each {|cell, v| cell.send("#{name}=".intern, v) }
        else
          @data = data.collect{|v| FlexObject.new(name, v) }
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
