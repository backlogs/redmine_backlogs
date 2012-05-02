require_dependency 'user'

module Backlogs
  module IssueRelationPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      IssueRelation.const_set("TYPE_OBSTRUCTS","obstructs");
      IssueRelation.const_set("TYPE_OBSTRUCTED","obstructed");
      IssueRelation.const_set("TYPE_CONTINUES","continues");
      IssueRelation.const_set("TYPE_CONTINUED","continued");

      base.const_set("TYPES", base.send(:remove_const,:TYPES).dup.merge({
        IssueRelation::TYPE_OBSTRUCTS =>  { :name => :label_duplicates, :sym_name => :label_duplicated_by, :order => 8, :sym => IssueRelation::TYPE_OBSTRUCTED },
        IssueRelation::TYPE_OBSTRUCTED =>  { :name => :label_duplicated_by, :sym_name => :label_duplicates, :order => 9, :sym => IssueRelation::TYPE_OBSTRUCTS, :reverse => IssueRelation::TYPE_OBSTRUCTS },
        IssueRelation::TYPE_CONTINUES =>  { :name => :label_duplicates, :sym_name => :label_duplicated_by, :order => 10, :sym => IssueRelation::TYPE_CONTINUED },
        IssueRelation::TYPE_CONTINUED =>  { :name => :label_duplicated_by, :sym_name => :label_duplicates, :order => 11, :sym => IssueRelation::TYPE_CONTINUES, :reverse => IssueRelation::TYPE_CONTINUES }
        }))
      puts IssueRelation::TYPES.inspect
      puts base.inspect
#           puts IssueRelation.TYPES.inspect
#          puts base.TYPES.inspect
#        end
    end
  
    module ClassMethods
    end
  
    module InstanceMethods

    end
  end
end

IssueRelation.send(:include, Backlogs::IssueRelationPatch) unless IssueRelation.included_modules.include? Backlogs::IssueRelationPatch
