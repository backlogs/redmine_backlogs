require_dependency 'user'

module Backlogs
  class Preference
    def initialize(user)
      @user = user
      @prefs = {}
    end

    def []=(attr, value)
      prefixed = "backlogs_#{attr}".intern

      case attr
        when :task_color
          value = value.to_s.strip
          value = "##{value}" if value =~ /^[0-9A-F]{6}$/i
          raise "Color format must be 6 hex digit string or empty, supplied value: #{value.inspect}" unless value == '' || value =~ /^#[0-9A-F]{6}$/i
          value.upcase!
        else
          raise "Unsupported attribute '#{attr}'"
      end

      @user.pref[prefixed] = value
      @prefs[prefixed] = value
      @user.pref.save!
    end

    def [](attr)
      prefixed = "backlogs_#{attr}".intern

      unless @prefs.include?(prefixed)
        value = @user.pref[prefixed].to_s.strip

        case attr
          when :task_color
            if value == '' # assign default
              colors = UserPreference.find(:all).collect{|p| p[prefixed].to_s.upcase}.select{|p| p != ''}
              min = 0x999999
              50.times do
                candidate = "##{(min + rand(0xFFFFFF-min)).to_s(16).upcase}"
                next if colors.include?(candidate)
                value = candidate
                break
              end
              self[attr] = value
            end

          when :task_color_light
            value = self[:task_color].to_s
            value = Backlogs::Color.new(value).lighten(0.5) unless value == ''

          else
            raise "Unsupported attribute '#{attr}'"
        end

        @prefs[prefixed] = value
      end

      return @prefs[prefixed]
    end
  end

  module UserPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)
    end

    module ClassMethods
    end

    module InstanceMethods

      def backlogs_preference
        @backlogs_preference ||= Backlogs::Preference.new(self)
      end

    end
  end
end

User.send(:include, Backlogs::UserPatch) unless User.included_modules.include? Backlogs::UserPatch
