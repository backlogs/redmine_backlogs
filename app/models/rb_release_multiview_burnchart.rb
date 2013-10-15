# Responsible for calculating data for a release multiview burnchart
# Takes care of limiting presentation of estimates within reasonable time frame.
class RbReleaseMultiviewBurnchart

  # Number of days to forecast
  ESTIMATE_DAYS = 120

  def initialize(multiview)

    @releases = multiview.releases

    # TODO Should the last date for closed data be removed?
    # Idea was to avoid showing closed points in the future which will
    # mess up with the estimates. Could also be that estimates should
    # make sure not to use newer data than today for estimates ?
    @stacked_graph = RbStackedData.new(Date.today + 30)
    @releases.each{|r|
      if r.has_burndown?
        release_data = {}
        release_data[:days] = r.days
        release_data[:total_points] = r.burndown[:total_points]
        release_data[:closed_points] = r.burndown[:closed_points]
        @stacked_graph.add(release_data,r,r.has_open_stories?)
      end
    }

    open_stories = @releases.inject(false) {|res,r| res |= r.has_open_stories? }
    @stacked_graph.finalize(open_stories)
  end


  def total_series
    series = []
    @stacked_graph.total_data.each{|s|
      series << s[:days].zip(s[:total_points])
    }
    series
  end

  def total_series_names
    names = []
    @stacked_graph.total_data.each{|s|
      names << s[:object].name
    }
    names
  end

  def estimate_series
    series = []
    return series if @stacked_graph.closed_estimate.nil?
    date_forecast_closed = Date.today
    @stacked_graph.total_estimates.each{|k,l|
      date_forecast = Date.today + ESTIMATE_DAYS
      date_forecast = l[:end_date_estimate] + 5.days if l[:end_date_estimate].nil? == false && (l[:end_date_estimate] > Date.today && l[:end_date_estimate] < date_forecast)
      date_forecast_closed = date_forecast if date_forecast > date_forecast_closed
      series << l[:trendline].predict_line(date_forecast)
    }
    series << @stacked_graph.closed_estimate.predict_line(date_forecast_closed)
    series
  end

  def estimate_series_names
    names = []
    @stacked_graph.total_estimates.each_key{|k|
      names << k.name + " estimate"
    }
    names << "Estimated accepted points"
    names
  end

  def closed_series
    @stacked_graph.closed_data[:days].zip(@stacked_graph.closed_data[:closed_points])
  end

  # Return all releases including trend information if available
  def releases_estimate
    releases_with_trends = []
    @releases.each{|r|
      trend_end_date = @stacked_graph.total_estimates[r][:end_date_estimate] unless @stacked_graph.total_estimates[r].nil?
      releases_with_trends << { :release => r,
        :trend_end_date => _estimate_text(r.has_open_stories?,trend_end_date)}
    }
    releases_with_trends
  end

private
  def _estimate_text(open_stories, end_date)
    if (open_stories === false)
      "Finished"
    elsif (end_date.nil?)
      "Not Available"
    elsif (end_date < Date.today)
      "Estimate in the past!"
    else
      end_date
    end
  end

end
