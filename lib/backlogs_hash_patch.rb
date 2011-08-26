require_dependency 'user'

module Backlogs
  module HashPatch
    def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
    end
  
    module ClassMethods
    end
  
    module InstanceMethods
      def transpose # assumes a hash of arrays
        self.values.transpose.map { |vs| Hash[self.keys.zip(vs)] }
      end
    end
  end
end

Hash.send(:include, Backlogs::HashPatch) unless Hash.included_modules.include? Backlogs::HashPatch
