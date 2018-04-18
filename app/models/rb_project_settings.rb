class RbProjectSettings < ActiveRecord::Base
  unloadable
  attr_protected :created_at # hack, all attributes will be mass asigment
  belongs_to :project
  attr_accessible :project_id
end

