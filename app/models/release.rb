require 'date'

class Release < Project
    unloadable

    validate :start_and_end_dates

    def start_and_end_dates
        errors.add_to_base("Sprint cannot end before it starts") if self.release_start_date && self.release_end_date && self.release_start_date >= self.release_end_date
    end

end
