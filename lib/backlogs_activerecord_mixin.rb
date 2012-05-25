module ActiveRecord
  module Backlogs

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

    module List
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_efficient_list(options={})
          class_eval <<-EOV
            include ActiveRecord::Backlogs::List::InstanceMethods

            def list_spacing
              #{options[:spacing] || 50}
            end

            def list_position
              self.#{options[:column] || :position}
            end

            def list_column
              :#{options[:column] || :position}
            end

            def find_position(p)
              return nil if p.blank?
              return self.class.find_by_#{options[:column] || :position}(pos)
            end

            before_create  :move_to_#{options[:default] || :top}

            private

            def list_position=(p)
              self.#{options[:column] || :position} = p
            end
          EOV

        end
      end

      module InstanceMethods
        def move_to_top
          list_position = self.first.list_position - list_spacing
        end

        def move_to_bottom
          list_position = self.last.list_position + list_spacing
        end

        def first(options = {})
          return find_position(self.class.minimum(list_column, options))
        end
        def last(options = {})
          return find_position(self.class.maximum(list_column, options))
        end

        def above(options = {})
          return list_prev_next(:prev, options)
        end

        def below(options = {})
          return list_prev_next(:next, options)
        end

        def move_after(reference)
          ref_pos = reference.list_position
          nxt = reference.below

          if nxt.blank?
            move_to_bottom
          else
            nxt_pos = nxt.list_position
            if (nxt_pos - ref_pos) < 2
              col = list_column
              @positioned.class.update_all("#{list_column} = #{list_column} + #{list_spacing}", "#{list_column} >= #{nxt_pos}")
              nxt_pos += list_spacing
            end
            list_position = (nxt_pos + ref_pos) / 2
          end
        end
      end

      private

      def list_prev_next(dir, options)
        options = options.dup
        add_condition(options, ["#{list_column} #{dir == :prev ? '<' : '>'} ?", list_position])
        options[:order] = "#{list_column} #{dir == :prev ? 'desc' : 'asc'}"
        return self.class.find(:first, options)
      end

      def add_condition(options, condition, conjunction = 'AND')
        if condition.is_a? String
          add_condition(options, [condition], conjunction)
        elsif condition.is_a? Hash
          add_condition!(options, [condition.keys.map { |attr| "#{attr}=?" }.join(' AND ')] + condition.values, conjunction)
        elsif condition.is_a? Array
          options[:conditions] ||= []
          options[:conditions][0] += " #{conjunction} (#{condition.shift})" unless options[:conditions].empty?
          options[:conditions] << condition
        else
          raise "don't know how to handle this condition type"
        end
      end

    end
  end
end
