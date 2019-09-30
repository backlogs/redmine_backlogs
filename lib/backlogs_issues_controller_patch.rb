require_dependency 'versions_controller'
require_dependency 'issues_controller'
require 'rubygems'
require 'nokogiri'
require 'json'

module Backlogs
  module VersionsControllerPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        after_action :add_backlogs_fields, :only => [:index, :show]
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def add_backlogs_fields
        case params[:format]
          when 'xml'
            body = Nokogiri::XML(response.body)
            body.xpath('//version').each{|version|
              release = Version.where(id: version.at('.//id').text)
              if release
                version << body.create_element('start_date', release[0]['sprint_start_date'])
              else
                version << body.create_element('start_date', '')
              end
            }
            response.body = body.to_xml
          when 'json'
            jsonp = (request.params[:callback] || request.params[:jsonp]).to_s.gsub(/[^a-zA-Z0-9_]/, '')
            body = JSON.parse(jsonp.present? ? response.body.sub("#{jsonp}(","").chop : response.body)
            (body['versions'] || [body['version']]).each{|version|
              release = Version.where(id: version['id'])
              if release
                version['start_date'] = release[0]['sprint_start_date']
              else
                version['start_date'] = ''
              end
            }
            response.body = jsonp.present? ? "#{jsonp}(#{body.to_json})" : body.to_json
        end
      end
    end
  end
  module IssuesControllerPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        unloadable # Send unloadable so it will not be unloaded in development
        after_action :add_backlogs_fields, :only => [:index, :show]
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def add_backlogs_fields
        story_trackers = RbStory.trackers

        case params[:format]
          when 'xml'
            body = Nokogiri::XML(response.body)
            body.xpath('//issue').each{|issue|
              issue << body.create_element('remaining_hours', RbStory.find(issue.at('.//id').text).remaining_hours.to_s)
              next unless story_trackers.include?(Integer(issue.at('.//tracker')['id']))
              issue << body.create_element('story_points', RbStory.find(issue.at('.//id').text).story_points.to_s)
              next unless RbStory.find(issue.at('.//id').text).release
              issue << body.create_element('release', :id => RbStory.find(issue.at('.//id').text).release_id.to_s,
                                                      :name => RbStory.find(issue.at('.//id').text).release.to_s)
            }
            response.body = body.to_xml
          when 'json'
            jsonp = (request.params[:callback] || request.params[:jsonp]).to_s.gsub(/[^a-zA-Z0-9_]/, '')
            body = JSON.parse(jsonp.present? ? response.body.sub("#{jsonp}(","").chop : response.body)
            (body['issues'] || [body['issue']]).each{|issue|
              issue['remaining_hours'] = RbStory.find(issue['id']).remaining_hours
              next unless story_trackers.include?(issue['tracker']['id'])
              issue['story_points'] = RbStory.find(issue['id']).story_points
              next unless RbStory.find(issue['id']).release
              issue['release'] = {:release => {:id=> RbStory.find(issue['id']).release_id, :name => RbStory.find(issue['id']).release.name}}
            }
            response.body = jsonp.present? ? "#{jsonp}(#{body.to_json})" : body.to_json
        end
      end
    end
  end
end

IssuesController.send(:include, Backlogs::IssuesControllerPatch) unless IssuesController.included_modules.include? Backlogs::IssuesControllerPatch
VersionsController.send(:include, Backlogs::VersionsControllerPatch) unless VersionsController.included_modules.include? Backlogs::VersionsControllerPatch
