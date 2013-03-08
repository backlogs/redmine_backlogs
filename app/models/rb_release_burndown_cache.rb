class RbReleaseBurndownCache < ActiveRecord::Base
  unloadable

  belongs_to :issue
  serialize :value, Hash

  def set(data)
    self.value = data
    self.save!
  end

  def get
    self.value
  end

end
