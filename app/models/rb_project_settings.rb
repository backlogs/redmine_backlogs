class RbProjectSettings < ActiveRecord::Base
  unloadable
  belongs_to :project
  attr_accessible :project_id
end

