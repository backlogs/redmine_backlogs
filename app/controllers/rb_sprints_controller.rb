include RbCommonHelper

# Responsible for exposing sprint CRUD. It SHOULD NOT be used
# for displaying the taskboard since the taskboard is a management
# interface used for managing objects within a sprint. For
# info about the taskboard, see RbTaskboardsController
class RbSprintsController < RbApplicationController
  unloadable

  def create
    attribs = params.select{|k,v| k != 'id' and RbSprint.column_names.include? k }
    attribs = Hash[*attribs.flatten]
    @sprint = RbSprint.new(attribs)

    begin
      @sprint.save!
    rescue => e
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    result = @sprint.errors.length
    status = (result == 0 ? 200 : 400)

    respond_to do |format|
      format.html { render :partial => "sprint", :status => status, :locals => { :sprint => @sprint } }
    end
  end

  def update
    attribs = params.select{|k,v| k != 'id' and RbSprint.column_names.include? k }
    attribs = Hash[*attribs.flatten]
    begin
      result  = @sprint.becomes(Version).update_attributes attribs
    rescue => e
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    respond_to do |format|
      format.html { render :partial => "sprint", :status => (result ? 200 : 400), :locals => { :sprint => @sprint } }
    end
  end

  def download
    bold = {:font => {:bold => true}}
    dump = BacklogsSpreadsheet::WorkBook.new
    ws = dump[@sprint.name]
    ws << [nil, @sprint.id, nil, nil, {:value => @sprint.name, :style => bold}, {:value => 'Start', :style => bold}] + @sprint.days(:all).collect{|d| {:value => d, :style => bold} }
    bd = @sprint.burndown
    bd.series(false).sort{|a, b| l("label_#{a}") <=> l("label_#{b}")}.each{ |k|
      ws << [ nil, nil, nil, nil, l("label_#{k}") ] + bd[k]
    }

    @sprint.stories.each{|s|
      ws << [s.tracker.name, s.id, nil, nil, {:value => s.subject, :style => bold}]
      bd = s.burndown
      bd.keys.sort{|a, b| l("label_#{a}") <=> l("label_#{b}")}.each{ |k|
        next if k == :status
        label = l("label_#{k}")
        label = {:value => label, :comment => k.to_s} if [:points, :points_accepted].include?(k)
        ws << [nil, nil, nil, nil, label ] + bd[k]
      }
      s.tasks.each {|t|
        ws << [nil, nil, t.tracker.name, t.id, {:value => t.subject, :style => bold}] + t.burndown
      }
    }

    send_data(dump.to_xml, :disposition => 'attachment', :type => 'application/vnd.ms-excel', :filename => "#{@project.identifier}-#{@sprint.name.gsub(/[^a-z0-9]/i, '')}.xml")
  end

  def reset
    unless @sprint.sprint_start_date
      render :text => 'Sprint without start date cannot be reset', :status => 400
      return
    end

    ids = []
    status = IssueStatus.default.id
    Issue.find(:all, :conditions => ['fixed_version_id = ?', @sprint.id]).each {|issue|
      ids << issue.id.to_s
      issue.update_attributes!(:created_on => @sprint.sprint_start_date.to_time, :status_id => status)
    }
    if ids.size != 0
      ids = ids.join(',')
      Issue.connection.execute("UPDATE issues SET updated_on = created_on WHERE id IN (#{ids})")

      Journal.connection.execute("DELETE FROM journal_details WHERE journal_id IN (SELECT id FROM journals WHERE journalized_type = 'Issue' AND journalized_id IN (#{ids}))")
      Journal.connection.execute("DELETE FROM journals WHERE (notes IS NULL OR notes = '') AND journalized_type = 'Issue' AND journalized_id IN (#{ids})")
      Journal.connection.execute("UPDATE journals
                                  SET created_on = (SELECT created_on
                                                    FROM issues
                                                    WHERE journalized_id = issues.id)
                                  WHERE journalized_type = 'Issue' AND journalized_id IN (#{ids})")
    end

    redirect_to :controller => 'rb_master_backlogs', :action => 'show', :project_id => @project.identifier
  end

  def close_completed
    @project.close_completed_versions if request.put?

    redirect_to :controller => 'rb_master_backlogs', :action => 'show', :project_id => @project
  end
end
