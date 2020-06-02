require_dependency 'custom_field'

module Backlogs
  module CustomFieldPatch
    def customized_class
      if self.respond_to?(:rb_sti_class)
        self.rb_sti_class.customized_class
      else
        super
      end
    end
  end
end

class CustomField
  class << self
    prepend Backlogs::CustomFieldPatch
  end
end