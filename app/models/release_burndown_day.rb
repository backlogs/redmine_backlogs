class ReleaseBurndownDay < ActiveRecord::Base
  unloadable
  belongs_to :rb_release, :foreign_key => :release_id
end
