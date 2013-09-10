class RbReleaseMultiview < ActiveRecord::Base
  self.table_name = 'rb_releases_multiview'

  unloadable

  belongs_to :project

  serialize :release_ids

  validates_presence_of :project_id, :name

  include Backlogs::ActiveRecord::Attributes

  def releases
    RbRelease.find(:all,:conditions => {:id => self.release_ids})
  end

end
