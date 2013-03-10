require 'rubygems'
require 'yaml'
require 'singleton'

unless defined?('ReliableTimout') || defined?(:ReliableTimout)
  if Backlogs.gems.include?('system_timer')
    require 'system_timer'
    ReliableTimout = SystemTimer
  else
    require 'timeout'
    ReliableTimout = Timeout
  end
end

module Backlogs
  def version
    root = File.expand_path('..', File.dirname(__FILE__))
    git = File.join(root, '.git')
    v = Redmine::Plugin.find(:redmine_backlogs).version

    g = nil
    if File.directory?(git)
      Dir.chdir(root)
      g = `git describe --tags --abbrev=10`
      g = "(#{g.strip})" if g
    end

    v = [v, g].compact.join(' ')
    v = '?' if v == ''
    return v
  end
  module_function :version

  def development?
    return !Rails.env.production?
  end
  module_function :"development?"

  def platform_support(raise_error = false)
    travis = nil # needed so versions isn't block-scoped in the timeout
    begin
      ReliableTimout.timeout(10) { travis = YAML::load(open('https://raw.github.com/backlogs/redmine_backlogs/master/.travis.yml').read) }
    rescue
      travis = YAML::load(File.open(File.join(File.dirname(__FILE__), '..', '.travis.yml')).read)
    end

    matrix = []
    travis['rvm'].each{|rvm|
      travis['env'].each{|env|
        matrix << {'ruby' => rvm, 'env' => env}
      }
    }

    travis['matrix']['exclude'].each{|exc|
      # if all values of the exclusion match, remove the cell
      matrix.delete_if{|cell| exc.keys.collect{|k| cell[k] == exc[k] ? '' : 'x'}.join('') == '' }
    } unless travis['matrix']['exclude'].nil?

    travis['matrix']['include'].each{|exc|
      rvm = exc['rvm']
      env = exc['env']
      matrix << {'ruby' => rvm, 'env' => env}
    } unless travis['matrix']['include'].nil?

    travis['matrix']['allow_failures'].each{|af|
      # if all values of the allowed failure match, the cell is unsupported
      matrix.each{|cell|
        cell[:unsupported] = true if af.keys.collect{|k| cell[k] == af[k] ? '' : 'x'}.join('') == ''
      }
    } unless travis['matrix']['allowed_failures'].nil?

    matrix.each{|cell|
      cell[:version] = cell.delete('env').gsub(/^REDMINE_VER=/, '').gsub(/\s.*/, '')
      cell[:platform] = (cell[:version] =~ /^[0-9]/ ? :redmine : :chiliproject)
    }

    plugin_version = Redmine::Plugin.find(:redmine_backlogs).version
    return "#{Redmine::VERSION}. You are running backlogs #{plugin_version}, latest version is #{travis['release']}" if plugin_version != travis['release']

    supported = matrix.select{|cell| cell[:platform] == platform}
    raise "Unsupported platform #{platform}" unless supported.size > 0

    platform_version = Redmine::VERSION.to_a.collect{|d| d.to_s}
    ruby_version = RUBY_VERSION.split('.')
    supported.each{|cell|
      v = cell[:version].split('.')
      next unless platform_version[0,v.length] == v

      v = cell[:ruby].split('.')
      next unless ruby_version[0,v.length] == v

      return "#{Redmine::VERSION}#{cell[:unsupported] ? '(unsupported but might work)' : ''}"
    }

    return "#{Redmine::VERSION} (DEVELOPMENT MODE)" if development?

    msg = "#{Redmine::VERSION} on #{RUBY_VERSION} (NOT SUPPORTED; please install #{platform} #{supported.reject{|v| v[:unsupported]}.collect{|v| "#{v[:version]} on #{v[:ruby]}"}.uniq.sort.join(' / ')}"
    raise msg if raise_error
    return msg
  end
  module_function :platform_support

  def os
    return :windows if RUBY_PLATFORM =~ /cygwin|windows|mswin|mingw|bccwin|wince|emx/
    return :unix if RUBY_PLATFORM =~ /darwin|linux/
    return :java if RUBY_PLATFORM =~ /java/
    return nil
  end
  module_function :os

  def gems
    installed = Hash[*(['json', 'system_timer', 'nokogiri', 'open-uri/cached', 'holidays', 'icalendar', 'prawn'].collect{|gem| [gem, false]}.flatten)]
    installed.delete('system_timer') unless os == :unix && RUBY_VERSION =~ /^1\.8\./
    installed.keys.each{|gem|
      begin
        require gem
        installed[gem] = true
      rescue LoadError
      end
    }
    return installed
  end
  module_function :gems

  def trackers
    return {:task => !!Tracker.find_by_id(RbTask.tracker), :story => !RbStory.trackers.empty?, :default_priority => !IssuePriority.default.nil?}
  end
  module_function :trackers

  def task_workflow(project)
    return false unless RbTask.tracker

    roles = User.current.roles_for_project(@project)
    tracker = Tracker.find(RbTask.tracker)

    [false, true].each{|creator|
      [false, true].each{|assignee|
        tracker.issue_statuses.each {|status|
          status.new_statuses_allowed_to(roles, tracker, creator, assignee).each{|s|
            return true
          }
        }
      }
    }
  end
  module_function :task_workflow

  def migrated?
    available = Dir[File.join(File.dirname(__FILE__), '../db/migrate/*.rb')].collect{|m| Integer(File.basename(m).split('_')[0].gsub(/^0+/, ''))}.sort
    return true if available.size == 0
    available = available[-1]

    ran = []
    Setting.connection.execute("select version from schema_migrations where version like '%-redmine_backlogs'").each{|m|
      ran << Integer((m.is_a?(Hash) ? m.values : m)[0].split('-')[0])
    }
    return false if ran.size == 0
    ran = ran.sort[-1]

    return ran >= available
  end
  module_function :migrated?

  def configured?(project=nil)
    return false if Backlogs.gems.values.reject{|installed| installed}.size > 0
    return false if Backlogs.trackers.values.reject{|configured| configured}.size > 0
    return false unless Backlogs.migrated?
    return false unless project.nil? || project.enabled_module_names.include?("backlogs")
    begin
      platform_support(true)
    rescue
      return false
    end

    return true
  end
  module_function :configured?

  def platform
    unless @platform
      begin
        ChiliProject::VERSION
        @platform = :chiliproject
      rescue NameError
        @platform = :redmine
      end
    end
    return @platform
  end
  module_function :platform

  class SettingsProxy
    include Singleton

    def [](key)
      key = key.intern if key.is_a?(String)
      settings = safe_load
      # add alternate loading because settings loading on ruby 1.9.3 seems to sometimes convert keys to strings on save.
      return settings[key] || settings[key.to_s]
    end

    def []=(key, value)
      key = key.intern if key.is_a?(String)
      settings = safe_load
      settings[key] = value
      Setting.plugin_redmine_backlogs = settings
    end

    def to_h
      h = safe_load
      h.freeze
      h
    end

    private

    def safe_load
      # At the first migration, the settings table will not exist
      return {} unless Setting.table_exists?

      settings = Setting.plugin_redmine_backlogs.dup
      if settings.is_a?(String)
        Rails.logger.error "Unable to load settings"
        return {}
      end
      settings
    end
  end

  def setting
    SettingsProxy.instance
  end
  module_function :setting
  def settings
    SettingsProxy.instance.to_h
  end
  module_function :settings
end
