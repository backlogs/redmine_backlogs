class RbProjectsettings < ActiveRecord::Base
  unloadable
  belongs_to :project
end

