require_dependency 'query'
require 'erb'

module Backlogs
  class RbERB
    def initialize(s)
      @sql = ERB.new(s)
    end

    def to_s
      return @sql.result
    end
  end

  module QueryPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      # Same as typing in the class
      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        base.add_available_column(QueryColumn.new(:story_points, :sortable => "#{Issue.table_name}.story_points"))
        base.add_available_column(QueryColumn.new(:velocity_based_estimate))
        base.add_available_column(QueryColumn.new(:position, :sortable => "#{Issue.table_name}.position"))
        base.add_available_column(QueryColumn.new(:remaining_hours, :sortable => "#{Issue.table_name}.remaining_hours"))

        alias_method_chain :available_filters, :backlogs_issue_type
        alias_method_chain :sql_for_field, :backlogs_issue_type
      end
    end

    module InstanceMethods
      def available_filters_with_backlogs_issue_type
        @available_filters = available_filters_without_backlogs_issue_type

        if RbStory.trackers.length == 0 or RbTask.tracker.blank?
          backlogs_filters = { }
        else
          backlogs_filters = {
            "backlogs_issue_type" => {  :type => :list,
                                        :values => [[l(:backlogs_story), "story"], [l(:backlogs_task), "task"], [l(:backlogs_impediment), "impediment"], [l(:backlogs_any), "any"]],
                                        :order => 20 },
            "story_points" => { :type => :float,
                                :order => 21 }
                             }
        end

        return @available_filters.merge(backlogs_filters)
      end

      def sql_for_field_with_backlogs_issue_type(field, operator, value, db_table, db_field, is_custom_filter=false)
        return sql_for_field_without_backlogs_issue_type(field, operator, value, db_table, db_field, is_custom_filter) unless field == "backlogs_issue_type"

        db_table = Issue.table_name

        sql = []

        selected_values = values_for(field)
        selected_values = ['story', 'task'] if selected_values.include?('any')

        story_trackers = RbStory.trackers(:type=>:string)
        all_trackers = (RbStory.trackers + [RbTask.tracker]).collect{|val| "#{val}"}.join(",")

        selected_values.each { |val|
          case val
            when "story"
              sql << "(#{db_table}.tracker_id in (#{story_trackers}))"

            when "task"
              sql << "(#{db_table}.tracker_id = #{RbTask.tracker})"

            when "impediment"
              sql << "(#{db_table}.id in (
                                select issue_from_id
                                from issue_relations ir
                                join issues blocked on
                                  blocked.id = ir.issue_to_id
                                  and blocked.tracker_id in (#{all_trackers})
                                where ir.relation_type = 'blocks'
                              ))"
          end
        }

        case operator
          when "="
            sql = sql.join(" or ")

          when "!"
            sql = "not (" + sql.join(" or ") + ")"
        end

        return sql
      end
    end

    module ClassMethods
      # Setter for +available_columns+ that isn't provided by the core.
      def available_columns=(v)
        self.available_columns = (v)
      end

      # Method to add a column to the +available_columns+ that isn't provided by the core.
      def add_available_column(column)
        self.available_columns << (column)
      end
    end
  end
end

Query.send(:include, Backlogs::QueryPatch) unless Query.included_modules.include? Backlogs::QueryPatch
