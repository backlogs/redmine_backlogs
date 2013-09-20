class RbReleaseMultiview < ActiveRecord::Base
  self.table_name = 'rb_releases_multiview'

  unloadable

  belongs_to :project

  serialize :release_ids

  validates_presence_of :project_id, :name

  include Backlogs::ActiveRecord::Attributes

  def releases
    RbRelease.find(:all,
                   :conditions => {:id => self.release_ids},
                   :order => "release_start_date ASC, release_end_date ASC")
  end

  def has_burnchart?
    return self.releases.size() > 0
  end

  def burnchart
    return nil unless self.has_burnchart?
    @cached_burnchart ||= RbReleaseMultiviewBurnchart.new(self)
    return @cached_burnchart
  end

end
