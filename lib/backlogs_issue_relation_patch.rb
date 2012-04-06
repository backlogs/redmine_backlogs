require_dependency 'user'

module Backlogs
  module IssueRelationPatch
    def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.send(:remove_const,:TYPES)
        IssueRelation.const_set("TYPE_OBSTRUCTS","obstructs");
        IssueRelation.const_set("TYPE_OBSTRUCTED","obstructed");
        IssueRelation.const_set("TYPE_CONTINUES","continues");
        IssueRelation.const_set("TYPE_CONTINUED","continued");
        base.const_set("TYPES",
          { IssueRelation::TYPE_RELATES =>     { :name => :label_relates_to, :sym_name => :label_relates_to, :order => 1, :sym => IssueRelation::TYPE_RELATES },
            IssueRelation::TYPE_DUPLICATES =>  { :name => :label_duplicates, :sym_name => :label_duplicated_by, :order => 2, :sym => IssueRelation::TYPE_DUPLICATED },
            IssueRelation::TYPE_DUPLICATED =>  { :name => :label_duplicated_by, :sym_name => :label_duplicates, :order => 3, :sym => IssueRelation::TYPE_DUPLICATES, :reverse => IssueRelation::TYPE_DUPLICATES },
            IssueRelation::TYPE_BLOCKS =>      { :name => :label_blocks, :sym_name => :label_blocked_by, :order => 4, :sym => IssueRelation::TYPE_BLOCKED },
            IssueRelation::TYPE_BLOCKED =>     { :name => :label_blocked_by, :sym_name => :label_blocks, :order => 5, :sym => IssueRelation::TYPE_BLOCKS, :reverse => IssueRelation::TYPE_BLOCKS },
            IssueRelation::TYPE_PRECEDES =>    { :name => :label_precedes, :sym_name => :label_follows, :order => 6, :sym => IssueRelation::TYPE_FOLLOWS },
            IssueRelation::TYPE_FOLLOWS =>     { :name => :label_follows, :sym_name => :label_precedes, :order => 7, :sym => IssueRelation::TYPE_PRECEDES, :reverse => IssueRelation::TYPE_PRECEDES },
            IssueRelation::TYPE_OBSTRUCTS =>  { :name => :label_duplicates, :sym_name => :label_duplicated_by, :order => 8, :sym => IssueRelation::TYPE_OBSTRUCTED },
            IssueRelation::TYPE_OBSTRUCTED =>  { :name => :label_duplicated_by, :sym_name => :label_duplicates, :order => 9, :sym => IssueRelation::TYPE_OBSTRUCTS, :reverse => IssueRelation::TYPE_OBSTRUCTS },
            IssueRelation::TYPE_CONTINUES =>  { :name => :label_duplicates, :sym_name => :label_duplicated_by, :order => 10, :sym => IssueRelation::TYPE_CONTINUED },
            IssueRelation::TYPE_CONTINUED =>  { :name => :label_duplicated_by, :sym_name => :label_duplicates, :order => 11, :sym => IssueRelation::TYPE_CONTINUES, :reverse => IssueRelation::TYPE_CONTINUES }
          })

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
