#!/usr/bin/env ruby

require 'yaml'
require 'net/http'
require 'uri'
require 'time'

class GitHub
  class HashClass
    def initialize(gh, data)
      @gh = gh
      @data = {}
      data.each_pair{|k, v| @data[k.to_sym] = v }
    end

    def method_missing(method_sym, *arguments, &block)
      return @data[method_sym] if @data.include?(method_sym)
      super
    end

    def respond_to?(method_sym, include_private = false)
      return true if @data.include?(method_sym)
      super
    end

    def to_s
      return @data.inspect
    end
  end

  class Comment < HashClass
  end

  class Issue < HashClass
    def comments
      @comments ||= YAML::load(@gh.get("issues/comments/:user/:repo/#{number}"))['comments'].collect { |c| Comment.new(@gh, c) }
    end

    def state
      return @data[:state].intern
    end

    def state=(new)
      raise "State can only be :open or :closed" unless [:open, :closed].include?(new)
    end

    def labels(which = :current)
      return @data[:labels] if which == :current

      l = @data[:labels].select{|l| !(l =~ /feedback/i || l.downcase == '1day' || l =~ /^[0-9]+days$/i) }

      if comments.size > 0
        if @gh.committers.include?(comments[-1].user) && !l.include?('feature-request') && !l.include?('in-progress')
          l << "feedback-required"

          date = comments[-1].updated_at
          diff = Integer((Time.now - date)) / (60 * 60 * 24)
          case diff
            when 0 then nil
            when 1 then l << '1day'
            else
              l << "#{diff}days"
              l << 'no-feedback' if diff > 4
          end
        end
      end
      return l.compact.uniq.collect{|lb| lb.downcase}
    end

    def labels=(new)
      old = labels
      remove = old - new
      add = new - old

      # post user and api key here
      remove.each {|l|
        @gh.post("issues/label/remove/:user/:repo/#{l}/#{number}")
      }
      add.each {|l|
        @gh.post("issues/label/add/:user/:repo/#{l}/#{number}")
      }
    end
  end

  CONFIGFILE = File.join(File.dirname(__FILE__), File.basename(__FILE__, File.extname(__FILE__))) + '.yaml'
  CONFIG = File.exists?(CONFIGFILE) ? YAML::load(File.open(CONFIGFILE)) : {}
  ROOT = 'http://github.com/api/v2/yaml/'

  def initialize(user, repo)
    @user = user
    @repo = repo
  end

  def get(url)
    url = url.gsub(/:user/, @user).gsub(/:repo/, @repo)
    url = "#{GitHub::ROOT}#{url}"
    return Net::HTTP.get(URI.parse(url))
  end

  def post(url)
    auth = {'login' => GitHub::CONFIG['username'], 'token' => GitHub::CONFIG['token']}
    url = url.gsub(/:user/, @user).gsub(/:repo/, @repo)
    url = "#{GitHub::ROOT}#{url}"
    r = Net::HTTP.post_form(URI.parse(url), auth)
    return r.body if r.is_a?(Net::HTTPSuccess)
    raise "#{url}: #{r.message} (#{auth.inspect})"
  end

  def issues(state = :open)
    return YAML::load(get("issues/list/:user/:repo/#{state}"))['issues'].collect { |i| Issue.new(self, i) }
  end

  def issue(id)
    return Issue.new(self, YAML::load(get("issues/show/:user/:repo/#{id}"))['issue'])
  end

  def labels(which = :all)
    return YAML::load(get('issues/labels/:user/:repo'))['labels'] if which == :all
    return issues.collect{|i| i.labels}.flatten.compact.uniq if which == :active
    return (issues.collect{|i| i.labels(:calculate)}.flatten + fixed_states).compact.uniq if which == :calculate
    raise "Unexpected selector #{which.inspect}"
  end

  def labels=(new)
    old = labels
    remove = old - new
    add = new - old

    # post user and api key here
    remove.each {|l|
      post("issues/label/remove/:user/:repo/#{l}")
    }
    add.each {|l|
      post("issues/label/add/:user/:repo/#{l}")
    }
  end

  def committers
    return ['friflaj']
  end

  def fixed_states
    ['in-progress', 'feedback-required', 'feature-request', 'release-blocker', 'no-feedback']
  end
end

begin
  gh = GitHub.new 'relaxdiego', 'redmine_backlogs'

  gh.labels = gh.labels(:calculate)
  gh.issues.each{|i|
    i.labels = i.labels(:calculate)
  }
rescue
  #
end
