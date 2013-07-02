require 'pp'

class RbIssueHistory < ActiveRecord::Base
  self.table_name = 'rb_issue_history'
  belongs_to :issue

  serialize :history, Array
  after_save :touch_sprint
  after_initialize :init_history
  after_create :update_parent

  def self.burndown_timezone(recalc=nil)
    #provide a ActiveSupport::TimeZone to calculate burndown day boundaries. Configured in global settings.
    #guarantees to return z timezone object, falling back gracefully.
    #To be backward compatible, fallback to ENV['TZ'] (server_tz) is provided first - that was the old behavior
    #Not considering ActiveSupport Time.zone (configured in config.time_zone for rails apps) - we provide our own configuration option
    @burndown_timezone = nil unless recalc.nil?
    @burndown_timezone ||= begin
      server_tz = ActiveSupport::TimeZone["Etc/GMT-#{Time.now.utc_offset/3600}"] rescue server_tz = nil
      fallback_tz = server_tz || ActiveSupport::TimeZone["UTC"]
      if Backlogs.settings[:burndown_timezone] #backlogs configuration for burndown day boundaries
        ActiveSupport::TimeZone[Backlogs.settings[:burndown_timezone]] || fallback_tz
      else
        fallback_tz
      end
    end
  end

  def self.statuses
    Hash.new{|h, k|
      s = IssueStatus.find_by_id(k.to_i)
      if s.nil?
        s = IssueStatus.default
        puts "IssueStatus #{k.inspect} not found, using default #{s.id} instead"
      end
      h[k] = {:id => s.id, :open => ! s.is_closed?, :success => s.is_closed? ? (s.default_done_ratio.nil? || s.default_done_ratio == 100) : false }
      h[k]
    }
  end

  def filter(sprint, status=nil)
    h = Hash[*(self.expand.collect{|d| [d[:date], d]}.flatten)]
    filtered = sprint.days.collect{|d| h[d] ? h[d] : {:date => d, :origin => :filter}}
    
    # see if this issue was closed after sprint end
    if filtered[-1][:status_open]
      self.history.select{|h| h[:date] > sprint.effective_date}.each{|h|
        if h[:sprint] == sprint.id && !h[:status_open]
          filtered[-1] = h
          break
        end
      }
    end
    return filtered
  end

  def filter_release(days)
    # if story is closed, make sure closed information is returned
    # from the end date of the sprint.
    closed_in_sprint = nil
    if self.issue.status.is_closed? && !self.issue.fixed_version.nil? && !self.issue.fixed_version.sprint_start_date.nil?
      # get closed history sorted by date
      #FIXME wishlist: history table column expansion to allow select and order by date
      h_closed = self.history.select{|h| h[:date] >= self.issue.fixed_version.sprint_start_date}.collect{|d| [d[:date],d]}.sort{|a,b| a[0] <=> b[0]}
      h_closed.each{|h|
        if !h[1][:status_open]
          closed_in_sprint = { :date => self.issue.fixed_version.effective_date, :history => h[1] }
          closed_in_sprint[:history][:origin] = :filter_closed_after
          break
        end
      }
    end

    # Fetch history to search for days
    h = Hash[*(self.history.collect{|d| [d[:date], d]}.flatten)]

    filtered = days.collect{|d|
      # if we are past date of closing issue just provide the closed history.
      if !closed_in_sprint.nil? && d >= closed_in_sprint[:date]
        closed_in_sprint[:history]
      else
        # Find closest date less than current day.
        closest_day = h.select{|k,v| k <= d }.sort[-1]
        closest_day ? closest_day[1] : {:date => d, :origin => :filter }
      end
    }
    return filtered
  end

  def self.issue_type(tracker_id)
    return nil if tracker_id.nil? || tracker_id == ''
    tracker_id = tracker_id.to_i
    return :story if RbStory.trackers && RbStory.trackers.include?(tracker_id)
    return :task if tracker_id == RbTask.tracker
    return nil
  end

  def expand
    # return a history array without gaps. If history has gaps, fill them with consecutive copies of each gap start day
    ((0..self.history.size - 2).to_a.collect{|i|
      (self.history[i][:date] .. self.history[i+1][:date] - 1).to_a.collect{|d|
        self.history[i].merge(:date => d)
      }
    } + [self.history[-1]]).flatten
  end

  def self.rebuild_issue(issue, status=nil)
    rb = RbIssueHistory.find_or_initialize_by_issue_id(issue.id)

    rb.history = [{:date => issue.created_on.to_date - 1, :origin => :rebuild}]

    status ||= self.statuses

    convert = lambda {|prop, v|
      if v.to_s == ''
        nil
      elsif [:estimated_hours, :remaining_hours, :story_points].include?(prop)
        Float(v)
      else
        Integer(v)
      end
    }

    full_journal = {}
    issue.journals.each{|journal|
      date = journal.created_on.to_date

      ## TODO: SKIP estimated_hours and remaining_hours if not a leaf node
      journal.details.each{|jd|
        next unless jd.property == 'attr' && ['estimated_hours', 'story_points', 'remaining_hours', 'fixed_version_id', 'status_id', 'tracker_id','release_id'].include?(jd.prop_key)

        prop = jd.prop_key.intern
        update = {:old => convert.call(prop, jd.old_value), :new => convert.call(prop, jd.value)}

        full_journal[date] ||= {}

        case prop
        when :estimated_hours, :remaining_hours # these sum to their parents
          full_journal[date][prop] = update
        when :story_points
          full_journal[date][prop] = update
        when :fixed_version_id
          full_journal[date][:sprint] = update
        when :status_id
          [:id, :open, :success].each_with_index{|status_prop, i|
            full_journal[date]["status_#{status_prop}".intern] = {:old => status[update[:old]][status_prop], :new => status[update[:new]][status_prop]}
          }
        when :tracker_id
          full_journal[date][:tracker] = {:old => RbIssueHistory.issue_type(update[:old]), :new => RbIssueHistory.issue_type(update[:new])}
        when :release_id
          full_journal[date][:release] = update
        else
          raise "Unhandled property #{jd.prop}"
        end
      }
    }

    if ActiveRecord::Base.connection.tables.include?('rb_journals')
      RbJournal.all(:conditions => ['issue_id=?', issue.id], :order => 'timestamp asc').each{|j|
        date = j.timestamp.to_date
        full_journal[date] ||= {}
        case j.property
        when 'story_points' then full_journal[date][:story_points] = {:new => j.value ? j.value.to_f : nil}
        when 'status_success' then full_journal[date][:status_success] = {:new => j.value == 'true'}
        when 'status_open' then full_journal[date][:status_open] = {:new => j.value == 'true'}
        when 'fixed_version_id' then full_journal[date][:sprint] = {:new => j.value ? j.value.to_i : nil}
        when 'release_id' then full_journal[date][:release] = {:new => j.value ? j.value.to_i : nil}
        when 'estimated_hours' then full_journal[date][:estimated_hours] = {:new => j.value ? j.value.to_f : nil}
        when 'remaining_hours' then full_journal[date][:remaining_hours] = {:new => j.value ? j.value.to_f : nil}
  
        else raise "Unexpected property #{j.property}: #{j.value.inspect}"
        end
  
        #:status_id is not in rb_journals
  
        full_journal[date][:tracker] ||= {:new =>
          case
          when issue.is_story? then :story
          when issue.is_task? then :task
          else nil
          end
        }
      }
    end

    full_journal[issue.updated_on.to_date] = {
      :story_points => {:new => issue.story_points},
      :sprint => {:new => issue.fixed_version_id },
      :release => {:new => issue.release_id },
      :status_id => {:new => issue.status_id },
      :status_open => {:new => status[issue.status_id][:open] },
      :status_success => {:new => status[issue.status_id][:success] },
      :tracker => {:new => RbIssueHistory.issue_type(issue.tracker_id) },
      :estimated_hours => {:new => issue.estimated_hours},
      :remaining_hours => {:new => issue.remaining_hours},
    }

    # Wouldn't be needed if redmine just created journals for update_parent_properties
    subissues = Issue.find(:all, :conditions => ['parent_id = ?', issue.id]).to_a
    subhists = []
    subdates = []
    subissues.each{|i|
      subdates.concat(i.history.history.collect{|h| h[:date]})
      subhists << Hash[*(i.history.expand.collect{|d| [d[:date], d]}.flatten)]
    }
    subdates.uniq!
    subdates.sort!

    subdates.sort.each{|date|
      next if date < issue.created_on.to_date

      current = {}
      full_journal.keys.sort.select{|d| d <= date}.each{|d|
        current[:sprint] = full_journal[d][:sprint][:new] if full_journal[d][:sprint]
        current[:release] = full_journal[d][:release][:new] if full_journal[d][:release]
        current[:estimated_hours] = full_journal[d][:estimated_hours][:new] if full_journal[d][:estimated_hours]
        current[:remaining_hours] = full_journal[d][:remaining_hours][:new] if full_journal[d][:remaining_hours]
        current[:tracker] = full_journal[d][:tracker][:new] if full_journal[d][:tracker]
      }
      next unless current[:tracker] # only process issues that exist at that date and are either story or task

      change = {
        :sprint => [],
        :release => [],
        :estimated_hours => [],
        :remaining_hours => [],
      }
      subhists.each{|h|
        [:sprint, :release, :remaining_hours, :estimated_hours].each{|prop|
          change[prop] << h[date][prop] if h[date] && h[date].include?(prop)
        }
      }
      [:sprint, :release].each{|key|
        change[key].uniq!
        change[key].sort!{|a, b|
          if a.nil? && b.nil?
            0
          elsif a.nil?
            1
          elsif b.nil?
            -1
          else
            a <=> b
          end
        }
      }

      [:remaining_hours, :estimated_hours].each{|prop|
        if change[prop].size == 0
          change.delete(prop)
        else
          change[prop] = change[prop].compact.sum
        end
      }

      if change[:sprint].size != 0 && current[:sprint] != change[:sprint][0]
        full_journal[date] ||= {}
        full_journal[date][:sprint] = {:old => current[:sprint], :new => change[:sprint][0]}
      end
      if change[:release].size != 0 && current[:release] != change[:release][0]
        full_journal[date] ||= {}
        full_journal[date][:release] = {:old => current[:release], :new => change[:release][0]}
      end
      if change.include?(:estimated_hours) && current[:estimated_hours] != change[:estimated_hours]
        full_journal[date] ||= {}
        full_journal[date][:estimated_hours] = {:old => current[:estimated_hours], :new => change[:estimated_hours]}
      end
      if change.include?(:remaining_hours) && current[:remaining_hours] != change[:remaining_hours]
        full_journal[date] ||= {}
        full_journal[date][:remaining_hours] = {:old => current[:remaining_hours], :new => change[:remaining_hours]}
      end
    }
    # End of child journal picking

    # process combined journal in order of timestamp into final history
    full_journal.keys.sort.collect{|date| {:date => date, :update => full_journal[date]} }.each {|entry|
      if entry[:date] != rb.history[-1][:date]
        rb.history << rb.history[-1].dup
        rb.history[-1][:date] = entry[:date]
      end

      entry[:update].each_pair{|prop, old_new|
        rb.history[0][prop] = old_new[:old] if old_new.include?(:old) && !rb.history[0].include?(prop)
        rb.history[-1][prop] = old_new[:new]
        rb.history.each{|h| h[prop] = old_new[:new] unless h.include?(prop) }
      }
    }

    # fill out journal so each journal entry is complete on each day
    rb.history.each{|h|
      h[:estimated_hours] = issue.estimated_hours             unless h.include?(:estimated_hours)
      h[:story_points] = issue.story_points                   unless h.include?(:story_points)
      h[:remaining_hours] = issue.remaining_hours             unless h.include?(:remaining_hours)
      h[:tracker] = RbIssueHistory.issue_type(issue.tracker_id)              unless h.include?(:tracker)
      h[:sprint] = issue.fixed_version_id                     unless h.include?(:sprint)
      h[:release] = issue.release_id                          unless h.include?(:release)
      h[:status_open] = status[issue.status_id][:open]        unless h.include?(:status_open)
      h[:status_success] = status[issue.status_id][:success]  unless h.include?(:status_success)

      h[:hours] = h[:remaining_hours] || h[:estimated_hours]
    }
    rb.history[-1][:hours] = rb.history[-1][:remaining_hours] || rb.history[-1][:estimated_hours]
    rb.history[0][:hours] = rb.history[0][:estimated_hours] || rb.history[0][:remaining_hours]

    rb.save

    if rb.history.detect{|h| h[:tracker] == :story }
      rb.history.collect{|h| h[:sprint] }.compact.uniq.each{|sprint_id|
        sprint = RbSprint.find_by_id(sprint_id)
        next unless sprint
        sprint.burndown.touch!(issue.id)
      }
    end
  end

  def self.rebuild
    RbSprintBurndown.delete_all

    status = self.statuses

    issues = Issue.count
    Issue.find(:all, :order => 'root_id asc, lft desc').each_with_index{|issue, n|
      puts "#{issue.id.to_s.rjust(6, ' ')} (#{(n+1).to_s.rjust(6, ' ')}/#{issues})..."
      RbIssueHistory.rebuild_issue(issue, status)
    }
  end

  def init_history
    self.history ||= []
    _issue = self.issue

    _statuses ||= self.class.statuses
    current = {
      :estimated_hours => _issue.estimated_hours,
      :story_points => _issue.story_points,
      :remaining_hours => _issue.remaining_hours,
      :tracker => RbIssueHistory.issue_type(_issue.tracker_id),
      :sprint => _issue.fixed_version_id,
      :release => _issue.release_id,
      :status_id => _issue.status_id,
      :status_open => _statuses[_issue.status_id][:open],
      :status_success => _statuses[_issue.status_id][:success],
      :origin => :default
    }

    #a sprint day lasts from 00:00:00 to 23:59:59 in configured timezone
    #Get the burndown_timezone || server-tz || utc as ActiveSupport::TimeZone object
    todo = []
    _today = self.class.burndown_timezone.now.to_date # current date in terms of burndown day boundary
    todo << _today.yesterday if self.history.size == 0
    todo << _today if self.history.size == 0 || self.history[-1][:date] != _today
    if todo.size > 0
      todo.each{|date|
        self.history << {:date => date}.merge(current)
        self.history[-1][:hours] = self.history[-1][:remaining_hours] || self.history[-1][:estimated_hours]
      }
    end

    self.history[-1].merge!(current)
    self.history[-1][:hours] = self.history[-1][:remaining_hours] || self.history[-1][:estimated_hours]
    self.history[0][:hours] = self.history[0][:estimated_hours] || self.history[0][:remaining_hours]

    raise "init_history failed: #{todo.inspect} => #{self.history.inspect}" unless self.history.size >= 2
  end

  def touch_sprint
    self.history.select{|h| h[:sprint]}.uniq{|h| "#{h[:sprint]}::#{h[:tracker]}"}.each{|h|
      sprint = RbSprint.find_by_id(h[:sprint])
      next unless sprint
      sprint.burndown.touch!(h[:tracker] == :story ? self.issue.id : nil)
    }
  end

  # normally, the update_parent_attributes of redmine would take care of re-saving parent issues where necessasy and thereby causing a history
  # regeneration. The exception to this is the creation-record in the history. This function handles that exception.
  # Upon each save, the history record for date `today' is set to the current value. That way, the history record for any date always holds the
  # latest value for that day -- essentially, the value it still had at midnight that day. So for the creation date of an issue, the history entry
  # for the date is was created holds the last value it had on that date. The value that the issue had (for the relevant properties that is) is
  # stored in the first history entry, dated the day *before* the creation date; it holds the values it had `midnight the day before', which
  # for our purposes means `the value it had at the start of the creation day'. This is very convenient for burndown calculation purposes, but
  # during the cascading re-save of parent issues, no save is triggered for the `yesterday' update, so properties that are calculated as the sum
  # of the children of an issue would be forgotton. To remedy this, this function is called after save of the history and updates the parent
  # history recursively *for that day only*. It will only be called once, which is when the history is created.
  def update_parent(date=nil)
    if (p = self.issue.parent) # if no parent, nothing to do
      date ||= self.history[0][:date] # the after_create calls this function without a parameter, so we know it's the creation call. Get the `yesterday' entry.
      parent_history_index = p.history.history.index{|d| d[:date] == date} # does the parent have an history entry on that date?
      if parent_history_index.nil? # if not, stretch the history to get the values at that date
        parent_data = p.history.expand.detect{|d| d[:date] == date} 
      else # if so, grab that entry
        parent_data = p.history.history[parent_history_index]
      end

      # if no entry is found, that means no history entry exists between that creation date and now, so the parent was created after the task. Nothing to do.
      return unless parent_data

      # we know this parent has children, because a child triggered this. Set the calculated fields to nil.
      [:estimated_hours, :remaining_hours, :hours].each{|h| parent_data[h] = nil }
      p.children.each{|child|
        child_data = child.history.expand.detect{|d| d[:date] == date } # get the history record for the child for that date
        next unless child_data # child didn't exist then, next

        # sum these values, if the child has any value for them. This keeps the value nil if all the children have it at nil.
        [:estimated_hours, :remaining_hours, :hours].each{|h| parent_data[h] = parent_data[h].to_i + child_data[h] if child_data[h] }
      }

      if parent_history_index.nil?
        # the record needs to be added, so add and sort (history needs to be sorted)
        p.history.history = (p.history.history + [parent_data]).sort{|a, b| a[:date] <=> b[:date]}
      else
        # there was an entry on this date, replace it
        p.history.history[parent_history_index] = parent_data
      end
      p.history.save

      # cascade, but pass on the date initialized by the after_create invocation.
      p.history.update_parent(date)
    end
  end
end
