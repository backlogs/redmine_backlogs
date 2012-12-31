#!/usr/bin/env ruby

require 'rubygems'
require 'octokit'
require 'inifile'
require 'time'
require 'yaml'

travis = YAML::load(open(File.join(File.dirname(__FILE__), '..', '..', '.travis.yml')))
SUPPORTED = {
  'backlogs' => travis['release'],
  'ruby' => travis['rvm'].join(', '),
  'platform' => (travis['env'] - travis['matrix']['allow_failures'].collect{|f| f['env']}).collect{|v|
    v = v.split.collect{|k| k.split(/=/)}.detect{|k| k[0]=='REDMINE_VER'}
    v.nil? ? nil : v[1]
  }.uniq.sort.join(', ')
}

class Issue
  def initialize(repo, issue)
    puts issue.number if STDOUT.tty?

    @repo = repo
    @issue = issue
    @labels = @issue.labels.collect{|l| l.name}

    @comments = @repo.client.issue_comments(@repo.repo, issue.number.to_s)

    @labels.delete_if{|l| l =~ /data-missing/ || l =~ /release/ || l == 'internal' || l=~ /attention/ || l =~ /feedback/i || l =~ /^[0-9]+days?$/i }

    @labels << 'release-blocker' if issue.milestone && issue.milestone == @repo.next_milestone

    if (@labels & ['on-hold', 'feature-request', 'IMPORTANT-READ']).size == 0 # any of these labels means it doesn't participate in the workflow
      body = "\n#{issue.body}\n"
      context = {}
      header = ''
      ['platform', 'backlogs', 'ruby'].each{|part|
        x = body.match(/\n#{part}:([^\n]+)\n/)
        body.gsub!(/\n#{part}:([^\n]+)\n/, "\n")
        x = x ? x[1].gsub(/#.*/, '').strip : ''
        context[part] = x
        header << "#{part}: #{x} # supported: #{SUPPORTED[part]}\n"
      }
      @labels << 'data-missing' if context.values.reject{|v| v == ''}.size != 3
      body = "#{header}\n#{body.strip}"
      @repo.client.update_issue(@repo.repo, issue.number, issue.title.to_s, body) if body != issue.body.to_s

      comment = {
        (@repo.collaborators.include?(issue.user.login) ? :collab : :user) => Time.parse(issue.created_at)
      }
      @comments.each{|c|
        comment[(@repo.collaborators.include?(c.user.login) ? :collab : :user)] = Time.parse(c.created_at)
      }

      response = comment[:collab] ? Integer((Time.now - comment[:collab])) / (60 * 60 * 24) : nil

      if comment[:user] && (comment[:collab].nil? || comment[:user] > comment[:collab])
        @labels << 'attention'
      elsif (comment[:user] && comment[:collab] && comment[:collab] >= comment[:user] && response < 5) || comment[:user].nil?
        @labels << 'feedback-required'
      elsif (comment[:user] && comment[:collab] && comment[:collab] >= comment[:user]) || comment[:user].nil?
        @labels << 'no-feedback'
        @labels << "#{response}days"
      end

      @labels.delete('attention') if @labels.include?('data-missing')

      @labels << 'internal' if comment[:user].nil?
    end

    if @labels.size == 0
      @repo.client.remove_all_labels(@repo.repo, issue.number)
    else
      @repo.client.replace_all_labels(@repo.repo, issue.number, @labels)
    end

    @labels.each{|l| @repo.labels[l] = :keep}
  end
end

class Repository
  def initialize(repo, config)
    @repo = repo
    @client = Octokit::Client.new(config)
    @collaborators = @client.collaborators(@repo).collect{|u| u.login}
    @labels = {}
    @client.labels(@repo).each{|label|
      label = label.name unless label.is_a?(String)
      @labels[label] = :delete
    }

    @milestones = @client.milestones(@repo, :state => 'open')
    @milestones.sort!{|a, b| a.title.split('.').collect{|v| v.rjust(10, '0')}.join('.') <=> b.title.split('.').collect{|v| v.rjust(10, '0')}.join('.') }
    @next_milestone = @milestones.size == 0 ? nil : @milestones[0]

    begin
      page ||= 0
      page += 1
      issues = @client.list_issues(@repo, :page => page, :state => 'open')
      issues.each{|i| Issue.new(self, i) }
    end while issues.size != 0

    @labels.each_pair{|l, status|
      next if status == :keep
      @client.delete_label!(@repo, l)
    }
  end

  attr_accessor :client, :repo, :collaborators, :labels, :milestones, :next_milestone
end

config = IniFile.load(File.expand_path('~/.gitconfig'))['github-issues']
config.keys.each{|k|
  sk = k.gsub(/[A-Z]/){|c| "_#{c.downcase}"}.intern
  config[sk] = config.delete(k)
}

begin
  Repository.new('backlogs/redmine_backlogs', config)
rescue => e
  raise e if STDOUT.tty?
end
