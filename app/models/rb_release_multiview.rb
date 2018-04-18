class RbReleaseMultiview < ActiveRecord::Base
  self.table_name = 'rb_releases_multiview'

  unloadable
  attr_protected :created_at # hack, all attributes will be mass asigment

  belongs_to :project

  attr_accessible :name, :project_id, :release_ids, :project, :description
  serialize :release_ids

  validates_presence_of :project_id, :name

  include Backlogs::ActiveRecord::Attributes

  def releases
    RbRelease.where(id: self.release_ids)
            .order("release_end_date ASC, release_start_date ASC").all
  end

  def has_burnchart?
    false #FIXME release burndown broken
    #releases.inject(false) {|result,release| result |= release.has_burndown?}
  end

  def burnchart
    return nil #FIXME release burndown broken
    #return nil unless self.has_burnchart?
    #@cached_burnchart ||= RbReleaseMultiviewBurnchart.new(self)
    #return @cached_burnchart
  end

end
