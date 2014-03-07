require 'date'

class RbTeam

  def initialize(project)
    @project = project     
    @current_date = Time.now.to_date
    print "\n\n\t\t", @current_date, "\n"
  end

  def success
    @success = "Successful creation."
  end

  def fail
    @fail = "Creation failed: sprints end before start."
  end

  def areAttributesAssignedCorrectly?(parameters) 

    @teams = "t"
    if Setting.plugin_redmine_backlogs[:number_of_teams].to_i == 1 then
      @teams += parameters[:t1].to_s
    else
      for i in 1..Setting.plugin_redmine_backlogs[:number_of_teams].to_i
        name = ":t" + i.to_s
        @teams += parameters[name].to_s
      end
    end

    @start_date = Time.new( parameters["form_start_date(1i)"],
                            parameters["form_start_date(2i)"],
                            parameters["form_start_date(3i)"]).to_date 

    @end_date = Time.new( parameters["form_end_date(1i)"],
                          parameters["form_end_date(2i)"],
                          parameters["form_end_date(3i)"]).to_date

    @sprint_title = Setting.plugin_redmine_backlogs[:alternative_sprint_name] + " " +
                    parameters[:partial_title] + " " +
                    Setting.plugin_redmine_backlogs[:teams_prefix_name]

    @params = { :sprint_title => @sprint_title,
                :start_date => @start_date.to_s,
                :end_date => @end_date.to_s,
                :teams => @teams }

    if(isCorrectDate?)
      printAssignedAttr
      return true
    else
      return false
    end
  end

  def getParams
    return @params
  end

  def printAssignedAttr
    print "Hash variable: ", @params, "_\n"
  end

  def isCorrectDate?
    if( @start_date < @end_date) then
      return true
    else
      return false
    end
  end

end
