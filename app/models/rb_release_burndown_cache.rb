class RbReleaseBurndownCache < ActiveRecord::Base
  unloadable

  belongs_to :issue
  serialize :value, Hash

  def set(days, data)
    self.value = {:data => data, :days => days}
    self.save!
  end

  def get(days)
    return nil if self.value.nil? || !acmp(self.value[:days], days)
    self.value[:data]
  end

  def drop
    self.value = nil
    self.save!
  end

  private

  def acmp(a, b)
    return false unless a.is_a? Array and b.is_a? Array
    ((a | b) - (a & b)).empty?
  end

end
