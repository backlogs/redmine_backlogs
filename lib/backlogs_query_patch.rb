require_dependency 'query'

module Backlogs
  module QueryPatch
    def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
  
        # Same as typing in the class 
        base.class_eval do
            unloadable # Send unloadable so it will not be unloaded in development
            base.add_available_column(QueryColumn.new(:story_points, :sortable => "#{Issue.table_name}.story_points"))
            base.add_available_column(QueryColumn.new(:remaining_hours, :sortable => "#{Issue.table_name}.remaining_hours"))
            base.add_available_column(QueryColumn.new(:velocity_based_estimate))

            base.add_available_column(QueryColumn.new(:position,
                                      :sortable => [
                                        # sprint startdate
                                        "coalesce((select start_date from sprints where sprints.id = issues.sprint_id), '1900-01-01')",

                                        # sprint name, in case start dates are the same
                                        "(select name from sprints where sprints.id = issues.sprint_id)",

                                        # make sure stories with NULL
                                        # position sort-last
                                        "(select case when root.position is null then 1 else 0 end from issues root where issues.root_id = root.id)",

                                        # story position
                                        "(select root.position from issues root where issues.root_id = root.id)",

                                        # story ID, in case positions
                                        # are the same (SHOULD NOT HAPPEN!).
                                        # DO NOT CHANGE; root_id is the only field that sorts the same for stories _and_
                                        # the tasks it has.
                                        "issues.root_id",

                                        # order in task tree
                                        "issues.lft"
                                      ],
                                      :default_order => 'asc'))

            base.add_available_column(QueryColumn.new(:sprint,
                                      :sortable => [
                                        # sprint startdate
                                        "coalesce((select start_date from sprints where sprints.id = issues.sprint_id), '1900-01-01')",

                                        # sprint name, in case start dates are the same
                                        "(select name from sprints where sprints.id = issues.sprint_id)"
                                      ],
                                      :default_order => 'asc'))

            alias_method_chain :available_filters, :backlogs
            alias_method_chain :sql_for_field, :backlogs
        end
  
    end
  
    module InstanceMethods
        def available_filters_with_backlogs
            @available_filters = available_filters_without_backlogs
  
            if Story.trackers.length == 0 or Task.tracker.blank?
                backlogs_filters = { }
            else
                backlogs_filters = {
                        "backlogs_issue_type" => {  :type => :list,
                                                    :values => [[l(:backlogs_story), "story"], [l(:backlogs_task), "task"], [l(:backlogs_any), "any"]],
                                                    :order => 20 },
                        "sprint" => {               :type => :list,
                                                    :values => Sprint.find(:all, :order => "coalesce(start_date, '1900-01-01'), name").collect{|s| [s.name, s.id]},
                                                    :order => 20 },
                        "open_sprint" => {          :type => :list,
                                                    :values => Sprint.find(:all, :conditions => ['end_date >= ?', Date.today], :order => "coalesce(start_date, '1900-01-01'), name").collect{|s| [s.name, s.id]},
                                                    :order => 20 },
                    }
            end
  
            return @available_filters.merge(backlogs_filters)
        end
  
        def sql_for_field_with_backlogs(field, operator, v, db_table, db_field, is_custom_filter=false)
            if field == "backlogs_issue_type"
                db_table = Issue.table_name
  
                sql = []
  
                selected_values = values_for(field)
                selected_values = ['story', 'task'] if selected_values.include?('any')
                
                selected_values.each { |val|
                    case val
                        when "story"
                            sql << "(#{db_table}.tracker_id in (" + Story.trackers.collect{|val| "#{val}"}.join(",") + ") and #{db_table}.parent_id is NULL)"
                        when "task"
                            sql << "(#{db_table}.tracker_id = #{Task.tracker} and not #{db_table}.parent_id is NULL)"
                    end
                }
  
                case operator
                    when "="
                        sql = sql.join(" or ")
                    when "!"
                        sql = "not (" + sql.join(" or ") + ")"
                end
  
                return sql
        
            elsif ['sprint', 'open_sprint'].include?(field)
              sprints = values_for(field).collect{|s| s.to_i.to_s}

              if sprints.size == 0
                sql = '(issues.sprint_id is null)'
              else
                sql = "(issues.sprint_id in (#{sprints.join(',')}))"
              end

              sql = "(not #{sql})" if operator == '!'
              return sql

            else
                return sql_for_field_without_backlogs(field, operator, v, db_table, db_field, is_custom_filter)
            end
      
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
