#!/usr/bin/env ruby

require 'rubygems'
require 'octokit'
require 'inifile'
require 'time'

config = IniFile.load(File.expand_path('~/.gitconfig'))['github-issues']
config[:login] = config.delete('user')
#config[:password] = config.delete('password')
config[:oauth_token] = config.delete('token')

REPO = "backlogs/redmine_backlogs"
CLIENT = Octokit::Client.new(config)

STATES = {
  'IMPORTANT-READ'    =>  [:keep, :no_feedback_required],
  'on-hold'           =>  [:keep, :no_feedback_required],
  'in-progress'       =>  [:keep, :no_feedback_required],
  'feature-request'   =>  [:keep, :no_feedback_required],
  'release-blocker'   =>  :keep,
  'no-feedback'       =>  :keep,
  'redmine2'          =>  :keep
}

class Issue
  @@collaborators = CLIENT.collaborators(REPO).collect{|u| u.login}

  def initialize(issue)
    @issue = issue
    @labels = issue.labels.collect{|l| l.name}
    @id = issue.number.to_s
    @comments = CLIENT.issue_comments(REPO, @id)
  end

  def self.states(cond)
    return STATES.keys.select{|k| STATES[k] == cond || (STATES[k].is_a?(Array) && STATES[k].include?(cond))}
  end

  def labels(action = nil)
    return @labels if action.nil?

    oldlabels = @labels.dup

    l = @labels.reject{|l| l =~ /feedback/i || l =~ /^[0-9]+days?$/i }

    if @comments.size > 0
      # last comment by a repo committer and not labeled with a 'no-feedback-required' label
      if @@collaborators.include?(@comments[-1].user.login) && (l & Issue.states(:no_feedback_required)).size == 0
        l << "feedback-required"

        last_non_collab_comment = nil
        @comments.reverse.each{|c|
          next if @@collaborators.include?(c.user.login)
          last_non_collab_comment = Time.parse(c.updated_at)
        }

        if last_non_collab_comment
          diff = Integer((Time.now - last_non_collab_comment)) / (60 * 60 * 24)
          case diff
          when 0 then nil
          when 1 then l << '1day'
          else
            l << "#{diff}days"
            l << 'no-feedback' if diff > 4
          end
        end
      end
    end

    @labels = l.compact.uniq.collect{|lb| lb.downcase}
    CLIENT.replace_all_labels(REPO, @issue.number, @labels)
    @labels
  end

  attr_reader :id, :comments
end

issues = CLIENT.list_issues(REPO, :state => 'open').collect{|i| Issue.new(i)}
labels = Issue.states(:keep)
issues.each{|issue| labels = labels + issue.labels(:recalc) }
labels.uniq!
puts (CLIENT.labels(REPO).collect{|l| l.name} - labels).inspect
#(CLIENT.labels(REPO).collect{|l| l.name} - labels).each {|label| CLIENT.delete_label(REPO, label) }
