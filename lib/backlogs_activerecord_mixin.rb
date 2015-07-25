module Backlogs
  module ActiveRecord
    def add_condition(options, condition, conjunction = 'AND')
      #puts("add_condition op=#{options} cond=#{condition} conj=#{conjunction}")
      #4/0
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
        klass = self.class.respond_to?(:rb_sti_class) ? self.class.rb_sti_class : self.class
        CustomField.where("type = '#{klass.name}CustomField'").order('position')
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

            scope :backlog_scope, lambda{|opts={}| where(nil) }

            def self.list_spacing
              #{options[:spacing]}
            end

            def self.find_by_rank(r) #this is a scope, used only in tests. combine with backlogs_scope for project/sprint options
              self.order('#{self.table_name}.position').limit(1).offset(r - 1).first
            end

            before_create  :move_to_#{options[:default]}
          EOV
        end
      end

      module InstanceMethods
        def move_to_top()
          top = self.class.minimum(:position)
          return if self.position == top && !top.blank?
          self.position = top.blank? ? 0 : (top - self.class.list_spacing)
          list_commit
        end

        def move_to_bottom()
          bottom = self.class.maximum(:position)
          return if self.position == bottom && !bottom.blank?
          self.position = bottom.blank? ? 0 : (bottom + self.class.list_spacing)
          list_commit
        end

        def first()
          return self.class.find_by_position(self.class.minimum(:position))
        end

        def last()
          return self.class.find_by_position(self.class.maximum(:position))
        end

        def higher_item()
          @higher_item ||= list_prev_next(:prev)
        end
        attr_writer :higher_item

        def lower_item()
          @lower_item ||= list_prev_next(:next)
        end
        attr_writer :lower_item

        def list_with_gaps_options
          {}
        end

        def rank
          @rank ||= self.class.
            backlog_scope(self.list_with_gaps_options).
            where(["#{self.class.table_name}.position <= ?", self.position]).
            count
        end
        attr_writer :rank

        def move_after(reference)
          nxt = reference.send(:lower_item_unscoped)

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

        #issues are listed by position ascending, which is in rank descending. Higher means lower position
        #before means lower position
        def move_before(reference)
          prev = reference.send(:higher_item_unscoped)
          if prev.blank?
            move_to_top
          else
            if (reference.position - prev.position) < 2
              self.class.connection.execute("update #{self.class.table_name} set position = position - #{self.class.list_spacing} where position <= #{prev.position}")
              prev.position -= self.class.list_spacing
            end
            self.position = (reference.position + prev.position) / 2
          end

          list_commit
        end

      end

      private

      #higher item is the one with lower position. self is visually displayed below its higher item.
      def higher_item_unscoped()
        @higher_item_unscoped ||= list_prev_next(:prev, false)
      end

      def lower_item_unscoped()
        @lower_item_unscoped ||= list_prev_next(:next, false)
      end

      def list_commit
        self.class.connection.execute("update #{self.class.table_name} set position = #{self.position} where id = #{self.id}") unless self.new_record?
        #FIXME now the cached lower/higher_item are wrong during this request. So are those from our old and new peers.
      end

      def list_prev_next(dir, scoped=true)
        return nil if self.new_record?
        raise "#{self.class}##{self.id}: cannot request #{dir} for nil position" unless self.position
        whereclause = ["#{self.class.table_name}.position #{dir == :prev ? '<' : '>'} ?", self.position]
        orderclause = "#{self.class.table_name}.position #{dir == :prev ? 'desc' : 'asc'}"

        if scoped
          sc = self.class.backlog_scope(self.list_with_gaps_options)
        else
          sc = self.class
        end
        return sc.
          where(whereclause).
          order(orderclause).first
      end

    end
  end
end

ActiveRecord::Base.send(:include, Backlogs::ActiveRecord::ListWithGaps) unless ActiveRecord::Base.included_modules.include? Backlogs::ActiveRecord::ListWithGaps
