class RbProjectSettings < ActiveRecord::Base
  unloadable
  belongs_to :project
end

