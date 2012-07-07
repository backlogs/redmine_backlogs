#!/usr/bin/env ruby

require 'rubygems'
require 'github-v3-api'
require 'inifile'
require 'time'

config = IniFile.load(File.expand_path('~/.gitconfig'))['github-issues']
GITHUB = GitHubV3API.new(config['token'])
ORG = 'backlogs'
REPO = 'redmine_backlogs'

puts GITHUB.repos.get(ORG, REPO).list_collaborators.inspect
exit
#puts github.issues.list(:user => 'backlogs', :repo => 'redmine_backlogs').collect{|i| i.state}.uniq.inspect

class Issue
  STATES = {
    'IMPORTANT-READ'    =>  [:keep, :no_feedback_required],
    'on-hold'           =>  [:keep, :no_feedback_required],
    'in-progress'       =>  [:keep, :no_feedback_required],
    'feature-request'   =>  [:keep, :no_feedback_required],
    'release-blocker'   =>  :keep,
    'no-feedback'       =>  :keep,
    'redmine2'          =>  :keep
  }
  @@collaborators = GITHUB.repos.get(ORG, REPO).list_collaborators.collect{|u| u.login}

  def initialize(issue)
    @issue = issue
  end

  def self.states(cond)
    return Issue::STATES.keys.select{|k| Issue::STATES[k] == cond || (Issue::STATES[k].is_a?(Array) && Issue::STATES[k].include?(cond))}
  end

  def labels
    @issue.labels
  end

  def relabel!
    newlabels = labels.reject{|l| l =~ /feedback/i || l =~ /^[0-9]+days?$/i }

    if @issue.comments.size > 0
      # last comment by a repo committer and not labeled with a 'no-feedback-required' label
      if @@collaborators.include?(@comments[-1].user.login) && (newlabels & Issue.states(:no_feedback_required)).size == 0
        newlabels << "feedback-required"

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
            newlabels << "#{diff}days"
            newlabels << 'no-feedback' if diff > 4
          end
        end
      end
    end

    newlabels = newlabels.compact.uniq.collect{|lb| lb.downcase}
    repolabels = {}
    CLIENT.labels(REPO).each{|l| repolabels[l.name] = l}

    # remove unused labels from the issue
    (oldlabels - @labels).each{|l| CLIENT.remove_label(REPO, @issue.number, l) }

    # pre-declare new labels
    (@labels - repolabels.keys).each {|label| CLIENT.add_label(REPO, label) }
    # add new labels
    CLIENT.add_labels_to_an_issue(REPO, @issue.number, (@labels - oldlabels))

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
