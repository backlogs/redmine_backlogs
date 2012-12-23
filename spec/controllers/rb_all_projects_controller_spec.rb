require 'fast_spec_helper'

class ScrumStatistics
  def initialize(score)
    @score = score
  end
  def score
    @score
  end
end
class Project
  STATUS_ACTIVE = 1
  def initialize(score)
    @stats = ScrumStatistics.new(score)
  end
  def scrum_statistics
    @stats
  end
end
module RbCommonHelper
end
class ApplicationController
  def self.before_filter(*args)
  end
end
class Object
  def unloadable
  end
end

require 'rb_all_projects_controller'

describe RbAllProjectsController, "#statistics" do
  it "returns enabled active projects sorted by the scrum statistics score" do
    # Set up
    project1 = Project.new(1)
    project2 = Project.new(2)
    project3 = Project.new(3)
    unsorted_projects = [ project3, project1, project2 ]

    # Exercise && Verify
    RbCommonHelper.should_receive(:find_backlogs_enabled_active_projects).and_return(unsorted_projects)
    sorted_projects = [ project1, project2, project3 ]
    RbAllProjectsController.new.statistics.should eq(sorted_projects)

  end
end
