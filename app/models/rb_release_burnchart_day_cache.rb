# Release burnchart cache per day per story.
# Table layout optimized for quickly summing up release burncharts.
class RbReleaseBurnchartDayCache < ActiveRecord::Base
  belongs_to :issue
  belongs_to :release
end
