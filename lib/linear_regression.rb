
module Backlogs
  # Creates a linear fit of a set of days and data
  class LinearRegression
    attr_reader :slope # points/day
    attr_reader :intercept # estimated starting point from first day
    attr_reader :days

    # @param days array of dates in dataset
    # param data array of values
    def initialize(days, data)
      @days = days
      @data = data

      days_number = @days.collect{|d| (d - days.first).to_i }
      count = days_number.size.to_f
      # Least mean square (x=days_number, y=data)
      avg_x = days_number.sum / count
      avg_y = data.sum / count
      avg_xy = days_number.each.with_index.inject(0){|sum,(d,i)|
                      sum + (d * data[i]) } / count
      avg_xx = days_number.inject(0){|sum,d| sum + (d * d) } / count

      @slope = (avg_xy - (avg_x * avg_y)) / (avg_xx - (avg_x**2))
      @intercept = (avg_xx*avg_y - (avg_x*avg_xy)) / (avg_xx - (avg_x**2))
    end

    # Calculate date of linear fit crossing other line
    # Only return if lines are crossing in the future
    def crossing_date(other)
      trend_cross_days = (predict_value(@days.last) - other.predict_value(@days.last)) /
        (other.slope - @slope)
      return @days.last + trend_cross_days unless trend_cross_days.infinite? or trend_cross_days <= 0
    end

    # Return trendline in form of two points
    def predict_line(date)
      return [[@days.first,@intercept],[date, predict_value(date)]]
    end

    # Return predicted value for a given date.
    def predict_value(date)
      days_between = (date - @days.first).to_i
      return days_between * @slope + @intercept
    end
  end
end
