require 'date'

class Release < ActiveRecord::Base
    unloadable

    belongs_to :project
    has_many :release_burndown_days

    validate :start_and_end_dates

    def start_and_end_dates
        errors.add_to_base("Release cannot end before it starts") if self.release_start_date && self.release_end_date && self.release_start_date >= self.release_end_date
    end

    def stories
        return Story.product_backlog(@project)
    end

    def days(cutoff = nil)
        # assumes mon-fri are working days, sat-sun are not. this
        # assumption is not globally right, we need to make this configurable.
        cutoff = self.release_end_date if cutoff.nil?
        return (self.sprint_start_date .. cutoff).select {|d| (d.wday > 0 and d.wday < 6) }
    end

    def has_burndown?
        return !!(self.release_start_date and self.release_end_date and self.initial_story_points)
    end

end
