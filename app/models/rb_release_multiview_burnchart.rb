# Responsible for calculating data for a release multiview burnchart
class RbReleaseMultiviewBurnchart
  def initialize(multiview)

    @releases = multiview.releases

    @stacked_graph = RbStackedData.new(Date.today)
    @releases.each{|r|
      release_data = {}
      release_data[:days] = r.days
      release_data[:total_points] = r.burndown[:total_points]
      release_data[:closed_points] = r.burndown[:closed_points]
      @stacked_graph.add(release_data)
    }
  end

end
