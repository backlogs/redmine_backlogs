# Responsible for calculating data for a release multiview burnchart
class RbReleaseMultiviewBurnchart
  def initialize(multiview)

    @releases = multiview.releases

    # TODO Should the last date for closed data be removed?
    # Idea was to avoid showing closed points in the future which will
    # mess up with the estimates. Could also be that estimates should
    # make sure not to use new data than today for estimates?
    @stacked_graph = RbStackedData.new(Date.today + 30)
    @releases.each{|r|
      if r.has_burndown?
        release_data = {}
        release_data[:days] = r.days
        release_data[:total_points] = r.burndown[:total_points]
        release_data[:closed_points] = r.burndown[:closed_points]
        @stacked_graph.add(release_data,r.name)
      end
    }

    @stacked_graph.add_overlapping_days
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
      names << s[:name]
    }
    names
  end

  def closed_series
    @stacked_graph.closed_data[:days].zip(@stacked_graph.closed_data[:closed_points])
  end
end
