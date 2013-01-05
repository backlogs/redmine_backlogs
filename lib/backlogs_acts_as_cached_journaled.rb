module ActiveRecord; module Acts; end; end
module ActiveRecord::Acts::ActsAsRbCachedJournaled

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def acts_as_rb_cached_journaled(add_entry, dependants)
      after_save do |o|
        deps = dependants.nil? [] : self.send(dependants)
        ([self] + deps).each{|o| o.send(add_entry) }
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActiveRecord::Acts::ActsAsRbCachedJournaled
