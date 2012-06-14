#!/usr/bin/env ruby

require 'rubygems'
require 'octokit'
require 'inifile'
require 'time'

config = IniFile.load(File.expand_path('~/.gitconfig'))['github-issues']
config[:login] = config.delete('user')
config[:oauth_token] = config.delete('token')

client = Octokit::Client.new(config)
issues = client.list_issues("backlogs/redmine_backlogs", :state => 'open')

#class GitHub
#  STATES = {
#    'IMPORTANT-READ'    =>  [:keep, :no_feedback],
#    'on-hold'           =>  [:keep, :no_feedback],
#    'in-progress'       =>  [:keep, :no_feedback],
#    'feedback-required' =>  :keep,
#    'feature-request'   =>  [:keep, :no_feedback],
#    'release-blocker'   =>  :keep,
#    'no-feedback'       =>  :keep
#    }
#
#  class HashClass
#    def initialize(gh, data)
#      @gh = gh
#      @data = {}
#      data.each_pair{|k, v| @data[k.to_sym] = v }
#    end
#
#    def method_missing(method_sym, *arguments, &block)
#      return @data[method_sym] if @data.include?(method_sym)
#      super
#    end
#
#    def respond_to?(method_sym, include_private = false)
#      return true if @data.include?(method_sym)
#      super
#    end
#
#    def to_s
#      return @data.inspect
#    end
#  end
#
#  class Comment < HashClass
#  end
#
#  class Issue < HashClass
#    def comments
#      @comments ||= [@gh.get("issues/comments/:user/:repo/#{number}")['comments']].compact.flatten.collect { |c| Comment.new(@gh, c) }
#    end
#
#    def state
#      return @data[:state].intern
#    end
#
#    def state=(new)
#      raise "State can only be :open or :closed" unless [:open, :closed].include?(new)
#    end
#
#    def labels(which = :current)
#      return @data[:labels] if which == :current
#
#      l = @data[:labels].reject{|l| l =~ /feedback/i || l.downcase == '1day' || l =~ /^[0-9]+days$/i }
#
#      if comments.size > 0
#        # last comment by a repo committer and not labeled with a
#        # 'no-feedback' label
#        if @gh.committers.include?(comments[-1].user) && (l & GitHub.states(:no_feedback)).size == 0
#          l << "feedback-required"
#
#          req = nil
#          comments.reverse.each{|c|
#            break unless @gh.committers.include?(c.user)
#            req = c
#          }
#
#          date = req.updated_at
#          diff = Integer((Time.now - date)) / (60 * 60 * 24)
#          case diff
#            when 0 then nil
#            when 1 then l << '1day'
#            else
#              l << "#{diff}days"
#              l << 'no-feedback' if diff > 4
#          end
#        end
#      end
#      prio = nil
#      comments.each {|c|
#        next unless @gh.committers.include?(c.user)
#        prio = nil
#        m = c.body.match(/\s:([0-9]+):\s/)
#        m = c.body.match(/^:([0-9]+):\s/) unless m
#        m = c.body.match(/\s:([0-9]+):$/) unless m
#        m = c.body.match(/^:([0-9]+):$/) unless m
#        prio = m[1] if m
#      }
#      l << "prio-#{prio}" if prio
#      return l.compact.uniq.collect{|lb| lb.downcase}
#    end
#
#    def labels=(new)
#      old = labels
#      remove = old - new
#      add = new - old
#
#      # post user and api key here
#      remove.each {|l|
#        @gh.post("issues/label/remove/:user/:repo/#{CGI::escape(l)}/#{number}")
#      }
#      add.each {|l|
#        @gh.post("issues/label/add/:user/:repo/#{CGI::escape(l)}/#{number}")
#      }
#    end
#  end
#
#  CONFIGFILE = File.join(File.dirname(__FILE__), File.basename(__FILE__, File.extname(__FILE__))) + '.rc'
#  CONFIG = File.exists?(CONFIGFILE) ? YAML::load(File.open(CONFIGFILE)) : {}
#  ROOT = 'http://github.com/api/v2/json/'
#
#  def initialize(user, repo)
#    @user = user
#    @repo = repo
#  end
#
#  def get(url)
#    url = url.gsub(/:user/, @user).gsub(/:repo/, @repo)
#    url = "#{GitHub::ROOT}#{url}"
#    data = Net::HTTP.get(URI.parse(url))
#    exit if data == ''
#    begin
#      return JSON.parse(data)
#    rescue
#      File.open('/tmp/github-issues.txt', 'w') do |f|
#        f.write(data)
#      end
#      raise "Failed to load parsable data from #{url}, data in /tmp/github-issues.txt"
#    end
#  end
#
#  def post(url)
#    auth = {'login' => GitHub::CONFIG['username'], 'token' => GitHub::CONFIG['token']}
#    url = url.gsub(/:user/, @user).gsub(/:repo/, @repo)
#    url = "#{GitHub::ROOT}#{url}"
#    r = Net::HTTP.post_form(URI.parse(url), auth)
#    return r.body if r.is_a?(Net::HTTPSuccess)
#    raise "#{url}: #{r.message} (#{auth.inspect})"
#  end
#
#  def issues(state = :open)
#    return get("issues/list/:user/:repo/#{state}")['issues'].collect { |i| Issue.new(self, i) }
#  end
#
#  def issue(id)
#    return Issue.new(self, get("issues/show/:user/:repo/#{id}")['issue'])
#  end
#
#  def labels(which = :all)
#    return get('issues/labels/:user/:repo')['labels'] if which == :all
#    return issues.collect{|i| i.labels}.flatten.compact.uniq if which == :active
#    return (issues.collect{|i| i.labels(:calculate)}.flatten + GitHub.states(:keep)).compact.uniq if which == :calculate
#    raise "Unexpected selector #{which.inspect}"
#  end
#
#  def labels=(new)
#    old = labels
#    remove = old - new
#    add = new - old
#
#    # post user and api key here
#    remove.each {|l|
#      post("issues/label/remove/:user/:repo/#{l}")
#    }
#    add.each {|l|
#      post("issues/label/add/:user/:repo/#{l}")
#    }
#  end
#
#  def committers
#    @committers ||= get("repos/show/:user/:repo/collaborators")
#    raise @committers.inspect
#  end
#
#  def self.states(cond)
#    return GitHub::STATES.keys.select{|k| GitHub::STATES[k] == cond || (GitHub::STATES[k].is_a?(Array) && GitHub::STATES[k].include?(cond))}
#  end
#end
#
##begin
#  gh = GitHub.new 'backlogs', 'redmine_backlogs'
#
#  gh.labels = gh.labels(:calculate)
#  gh.issues.each{|i|
#    i.labels = i.labels(:calculate)
#  }
##rescue
#  #
##end
