require 'date'

class Release < Project
    unloadable

    belongs_to :project

    validate :start_and_end_dates

    def start_and_end_dates
        errors.add_to_base("Release cannot end before it starts") if self.start_date && self.end_date && self.start_date >= self.end_date
    end

end
