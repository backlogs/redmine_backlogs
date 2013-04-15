
module Backlogs
  class AverageTrend
    attr_reader :slope
    attr_reader :intercept

    # @param days array of dates in dataset
    # param data array of values
    def initialize(days, data)
      @days = days
      @data = data

      avg_days = (@days.last - @days.first).to_i
      @slope = (@data.last - @data.first) / avg_days
    end

    def crossing_date(other)
      trend_cross_days = (@data.last - other.predict_value(@days.last)) /
        (other.slope - @slope)
      return @days.last + trend_cross_days unless trend_cross_days.infinite? or trend_cross_days <= 0
    end

    # Return trendline in form of two points
    def predict_line(date)
      return [[@days.first,@data.first],[date, predict_value(date)]]
    end

    # Return predicted value for a given date.
    def predict_value(date)
      days_between = (date - @days.last).to_i
      return days_between * @slope + @data.last
    end
  end
end
