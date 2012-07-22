require_dependency 'issues_controller'
require 'rubygems'
require 'json'

module Backlogs
  module IssuesControllerPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        after_filter :add_backlogs_fields, :only => [:index]
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def add_backlogs_fields
        story_trackers = RbStory.trackers

        case params[:format]
          when 'xml'
            body = REXML::Document.new(response.body)
            REXML::XPath.each(body, '//issue') {|issue|
              next unless story_trackers.include?(Integer(REXML::XPath.first(issue, './tracker').attributes['id']))
              issue.add_element('story_points').text = RbStory.find(REXML::XPath.first(issue, './id').text).story_points.to_s
            }
            to_xml = ''
            body.write(to_xml)
            response.body = to_xml
          when 'json'
            body = JSON.parse(response.body)
            body['issues'].each{|issue|
              next unless story_trackers.include?(issue['tracker']['id'])
              issue['story_points'] = RbStory.find(issue['id']).story_points
            }
            response.body = body.to_json
        end
      end
    end
  end
end

IssuesController.send(:include, Backlogs::IssuesControllerPatch) unless IssuesController.included_modules.include? Backlogs::IssuesControllerPatch
