require 'pp'

class RbSprintHistory < ActiveRecord::Base
  set_table_name 'rb_sprint_history'
  belongs_to :version

  serialize :issues, Array
  after_initialize :set_default_issues

  private

  def set_default_issues
    self.issues ||= []
  end
end
