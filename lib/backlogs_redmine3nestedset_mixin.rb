require_dependency 'issue'

module Backlogs
  module NestedSetPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
    end

    module ClassMethods
    end

    module InstanceMethods
      def right_sibling
        siblings.where(["#{self.class.table_name}.lft > ?", lft]).first
      end

      def move_to(target, position)
        puts("Not implemented: '#{self}'.move_to '#{target}' '#{position}'")
        Rails.logger.error("Not implemented: '#{self}'.move_to '#{target}' '#{position}'")
        #3/0
      end

      # Move the node to the left of another node (you can pass id only)
      def move_to_left_of(node)
        move_to node, :left
      end

      # Move the node to the left of another node (you can pass id only)
      def move_to_right_of(node)
        move_to node, :right
      end

    end
  end
end

Issue.send(:include, Backlogs::NestedSetPatch) unless Issue.included_modules.include? Backlogs::NestedSetPatch
