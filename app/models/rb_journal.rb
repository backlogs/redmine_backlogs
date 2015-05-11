class RbJournal < ActiveRecord::Base
  unloadable
  attr_protected :created_at # hack, all attributes will be mass asigment
end
