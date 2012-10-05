#!/usr/bin/env ruby

require 'rubygems'
require 'octokit'
require 'inifile'
require 'time'
require 'workflow' # http://www.geekq.net/workflow/

config = IniFile.load(File.expand_path('~/.gitconfig'))['github-issues']
config.keys.each{|k|
  sk = k.gsub(/[A-Z]/){|c| "_#{c.downcase}"}.intern
  config[sk] = config.delete(k)
}

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
      if @@collaborators.include?(@comments[-1].user.login)
        if (l & Issue.states(:no_feedback_required)).size == 0
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
      else
        if (l & Issue.states(:no_feedback_required)).size == 0
          l << 'attention'
        end
      end
    end

    puts "#{@id}: #{@labels.inspect}"
    @labels = l.compact.uniq.collect{|lb| lb.downcase}
    if @labels.size == 0
      CLIENT.remove_all_labels(REPO, @issue.number)
    else
      CLIENT.replace_all_labels(REPO, @issue.number, @labels)
    end
    @labels
  end

  attr_reader :id, :comments
end

begin
  page ||= 0
  page += 1
  issues = CLIENT.list_issues(REPO, :page => page, :state => 'open').collect{|i| Issue.new(i)}
  issues.each{|issue| issue.labels(:save) }
end while issues.size != 0
