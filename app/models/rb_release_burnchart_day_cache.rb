# Release burnchart cache per day per story.
# Table layout optimized for quickly summing up release burncharts.
class RbReleaseBurnchartDayCache < ActiveRecord::Base
  unloadable
  attr_protected :created_at # hack, all attributes will be mass asigment
  belongs_to :issue
  belongs_to :release

end
