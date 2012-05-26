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
      def batch_modify_attributes(attribs)
        attribs.each_pair{|k, v|
          # I can't find any damn combination of safe_attributes that works
          next if ['parent_id', 'rgt', 'lft'].include?(k)
  
          begin
            self.send("#{k}=", v)
          rescue => e
            puts "#{e} for #{k} = #{v}"
          end
        }
      end
  
      def batch_update_attributes!(attribs)
        self.batch_modify_attributes(attribs)
        return self.save!
      end
      def journalized_batch_update_attributes!(attribs)
        self.init_journal(User.current)
        return self.batch_update_attributes!(attribs)
      end
      def batch_update_attributes(attribs)
        self.batch_modify_attributes(attribs)
        return self.save
      end
      def journalized_batch_update_attributes(attribs)
        self.init_journal(User.current)
        return self.batch_update_attributes(attribs)
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
          class_eval <<-EOV
            include Backlogs::ActiveRecord::ListWithGaps::InstanceMethods

            def self.list_spacing
              #{options[:spacing] || 50}
            end

            def list_position
              self.#{options[:column] || :position}
            end

            def self.list_column
              \"#{self.table_name}.#{options[:column] || :position}\"
            end

            def find_position(p)
              return nil if p.blank?
              return self.class.find_by_#{options[:column] || :position}(p)
            end

            before_create  :move_to_#{options[:default] || :top}

            private

            def list_position=(p)
              self.#{options[:column] || :position} = p
            end

            def self.find_by_rank(r, options)
              self.find(:first, options.merge(:order => self.list_column, :limit => 1, :offset => r - 1))
            end
          EOV
        end
      end

      module InstanceMethods
        def move_to_top
          list_position = self.first.list_position - self.class.list_spacing
        end

        def move_to_bottom
          list_position = self.last.list_position + self.class.list_spacing
        end

        def first(options = {})
          return find_position(self.class.minimum(self.class.list_column, options))
        end
        def last(options = {})
          return find_position(self.class.maximum(self.class.list_column, options))
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
          Backlogs::ActiveRecord.add_condition(options, ["#{self.class.list_column} <= ?", list_position])
          @rank ||= self.class.count(options)
        end
        attr_writer :rank

        def move_after(reference, options={})
          options[:commit] = true unless options.include?(:commit)

          ref_pos = reference.list_position
          nxt = reference.lower_item

          if nxt.blank?
            move_to_bottom
          else
            nxt_pos = nxt.list_position
            if (nxt_pos - ref_pos) < 2
              col = self.class.list_column
              self.class.update_all("#{self.class.list_column} = #{self.class.list_column} + #{self.class.list_spacing}", "#{self.class.list_column} >= #{nxt_pos}")
              nxt_pos += self.class.list_spacing
            end
            list_position = (nxt_pos + ref_pos) / 2
          end

          self.save! if options[:commit]
        end
      end

      private

      def list_prev_next(dir, options)
        return nil if self.new_record?
        raise "#{self.class}##{self.id}: cannot request #{dir} for nil position" unless list_position
        options = options.dup
        Backlogs::ActiveRecord.add_condition(options, ["#{self.class.list_column} #{dir == :prev ? '<' : '>'} ?", list_position])
        options[:order] = "#{self.class.list_column} #{dir == :prev ? 'desc' : 'asc'}"
        return self.class.find(:first, options)
      end

    end
  end
end

ActiveRecord::Base.send(:include, Backlogs::ActiveRecord::ListWithGaps) unless ActiveRecord::Base.included_modules.include? Backlogs::ActiveRecord::ListWithGaps
