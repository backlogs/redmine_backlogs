require_dependency 'custom_field'

module Backlogs
  module CustomFieldPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
      base.class_eval do
        class << self
          alias_method_chain :customized_class, :sti
        end
      end
    end

    module ClassMethods
      def customized_class_with_sti
        (self.respond_to?(:rb_sti_class) ? self.rb_sti_class : self).customized_class_without_sti
      end
    end

    module InstanceMethods
    end
  end
end

CustomField.send(:include, Backlogs::CustomFieldPatch) unless CustomField.included_modules.include? Backlogs::CustomFieldPatch
