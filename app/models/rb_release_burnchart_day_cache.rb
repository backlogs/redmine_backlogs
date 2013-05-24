# Release burnchart cache per day per story.
# Table layout optimized for quickly summing up release burncharts.
class RbReleaseBurnchartDayCache < ActiveRecord::Base
  unloadable
  belongs_to :issue
  belongs_to :release

end
