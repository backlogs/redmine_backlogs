module Backlogs
  module ActiveRecord
    def add_condition(options, condition, conjunction = 'AND')
      if condition.is_a? String
        add_condition(options, [condition], conjunction)
      elsif condition.is_a? Hash
        add_condition!(options, [condition.keys.map { |attr| "#{attr}=?" }.join(' AND ')] + condition.values, conjunction)
      elsif condition.is_a? Array
        options[:conditions] ||= []
        options[:conditions][0] += " #{conjunction} (#{condition.shift})" unless options[:conditions].empty?
        options[:conditions] = options[:conditions] + condition
      else
        raise "don't know how to handle this condition type"
      end
    end
    module_function :add_condition

    module Attributes
      def self.included receiver
        receiver.extend ClassMethods
      end

      module ClassMethods
        def rb_sti_class
          return self.ancestors.select{|klass| klass.name !~ /^Rb/ && klass.ancestors.include?(::ActiveRecord::Base)}[0]
        end
      end

      def available_custom_fields
        CustomField.find(:all, :conditions => "type = '#{self.class.rb_sti_class.name}CustomField'", :order => 'position')
      end

      def journalized_update_attributes!(attribs)
        self.init_journal(User.current)
        return self.update_attributes!(attribs)
      end
      def journalized_update_attributes(attribs)
        self.init_journal(User.current)
        return self.update_attributes(attribs)
      end
      def journalized_update_attribute(attrib, v)
        self.init_journal(User.current)
        return self.update_attribute(attrib, v)
      end
    end

    module ListWithGaps
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_list_with_gaps(options={})
          options[:spacing] ||= 50
          options[:default] ||= :top

          class_eval <<-EOV
            include Backlogs::ActiveRecord::ListWithGaps::InstanceMethods

            def self.list_spacing
              #{options[:spacing]}
            end

            def self.find_by_rank(r, options)
              self.find(:first, options.merge(:order => '#{self.table_name}.position', :limit => 1, :offset => r - 1))
            end

            before_create  :move_to_#{options[:default]}
          EOV
        end
      end

      module InstanceMethods
        def move_to_top(options={})
          top = self.class.minimum(:position)
          return if self.position == top && !top.blank?
          self.position = top.blank? ? 0 : (top - self.class.list_spacing)
          list_commit
        end

        def move_to_bottom(options={})
          bottom = self.class.maximum(:position)
          return if self.position == bottom && !bottom.blank?
          self.position = bottom.blank? ? 0 : (bottom + self.class.list_spacing)
          list_commit
        end

        def first(options = {})
          return self.class.find_by_position(self.class.minimum(:position, options))
        end

        def last(options = {})
          return self.class.find_by_position(self.class.maximum(:position, options))
        end

        def higher_item(options = {})
          @higher_item ||= list_prev_next(:prev, options)
        end
        attr_writer :higher_item

        def lower_item(options = {})
          @lower_item ||= list_prev_next(:next, options)
        end
        attr_writer :lower_item

        def rank(options={})
          options = options.dup
          Backlogs::ActiveRecord.add_condition(options, ["#{self.class.table_name}.position <= ?", self.position])
          @rank ||= self.class.count(options)
        end
        attr_writer :rank

        def move_after(reference, options={})
          nxt = reference.lower_item

          if nxt.blank?
            move_to_bottom
          else
            if (nxt.position - reference.position) < 2
              self.class.connection.execute("update #{self.class.table_name} set position = position + #{self.class.list_spacing} where position >= #{nxt.position}")
              nxt.position += self.class.list_spacing
            end
            self.position = (nxt.position + reference.position) / 2
          end

          list_commit
        end
      end

      private

      def list_commit
        self.class.connection.execute("update #{self.class.table_name} set position = #{self.position} where id = #{self.id}") unless self.new_record?
      end

      def list_prev_next(dir, options)
        return nil if self.new_record?
        raise "#{self.class}##{self.id}: cannot request #{dir} for nil position" unless self.position
        options = options.dup
        Backlogs::ActiveRecord.add_condition(options, ["#{self.class.table_name}.position #{dir == :prev ? '<' : '>'} ?", self.position])
        options[:order] = "#{self.class.table_name}.position #{dir == :prev ? 'desc' : 'asc'}"
        return self.class.find(:first, options)
      end

    end
  end
end

ActiveRecord::Base.send(:include, Backlogs::ActiveRecord::ListWithGaps) unless ActiveRecord::Base.included_modules.include? Backlogs::ActiveRecord::ListWithGaps
