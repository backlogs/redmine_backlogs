include RbCommonHelper

# Responsible for exposing sprint CRUD. It SHOULD NOT be used
# for displaying the taskboard since the taskboard is a management
# interface used for managing objects within a sprint. For
# info about the taskboard, see RbTaskboardsController
class RbSprintsController < RbApplicationController
  unloadable

  # Accept download as API request as Redmine redirects XML format to this type
  accept_api_auth :download

  def create
    attribs = params.select{|k,v| k != 'id' and RbSprint.column_names.include? k }
    attribs = Hash[*attribs.flatten]
    @sprint = RbSprint.new(attribs)

    #share the sprint according to the global setting
    default_sharing = Backlogs.setting[:sharing_new_sprint_sharingmode]
    if default_sharing 
      if @sprint.allowed_sharings.include? default_sharing
        @sprint.sharing = default_sharing
      end
    end

    begin
      @sprint.save!
    rescue => e
      Rails.logger.debug e
      Rails.logger.debug e.backtrace.join("\n")
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    result = @sprint.errors.size
    status = (result == 0 ? 200 : 400)

    respond_to do |format|
      format.html { render :partial => "sprint", :status => status, :locals => { :sprint => @sprint, :cls => 'model sprint' } }
    end
  end

  def update
    except = ['id', 'project_id']
    attribs = params.select{|k,v| (!except.include? k) and (RbSprint.column_names.include? k) }
    attribs = Hash[*attribs.flatten]
    begin
      result  = @sprint.update_attributes attribs
    rescue => e
      Rails.logger.debug e
      Rails.logger.debug e.backtrace.join("\n")
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    respond_to do |format|
      format.html { render :partial => "sprint", :status => (result ? 200 : 400), :locals => { :sprint => @sprint, :cls => 'model sprint' } }
    end
  end

  def download
    bold = {:font => {:bold => true}}
    dump = BacklogsSpreadsheet::WorkBook.new
    ws = dump[@sprint.name]
    ws << [nil, @sprint.id, nil, nil, {:value => @sprint.name, :style => bold}, {:value => 'Start', :style => bold}] + @sprint.days.collect{|d| {:value => d, :style => bold} }
    bd = @sprint.burndown
    bd.series(false).sort{|a, b| l("label_#{a}") <=> l("label_#{b}")}.each{ |k|
      ws << [ nil, nil, nil, nil, l("label_#{k}") ] + bd.data[k.to_sym]
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
        ws << [nil, nil, t.tracker.name, t.id, {:value => t.subject, :style => bold}] + t.becomes(RbTask).burndown
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
    Issue.where(fixed_version_id: @sprint.id).find_each {|issue|
      ids << issue.id.to_s
      issue.update_attributes!(:created_on => @sprint.sprint_start_date.to_time, :status_id => status)
    }
    if ids.size != 0
      ids = ids.join(',')
      Issue.connection.execute("update issues set updated_on = created_on where id in (#{ids})")

      Journal.connection.execute("delete from journal_details where journal_id in (select id from journals where journalized_type = 'Issue' and journalized_id in (#{ids}))")
      Journal.connection.execute("delete from journals where (notes is null or notes = '') and journalized_type = 'Issue' and journalized_id in (#{ids})")
      Journal.connection.execute("update journals
                                   set created_on = (select created_on
                                                     from issues
                                                     where journalized_id = issues.id)
                                   where journalized_type = 'Issue' and journalized_id in (#{ids})")
    end

    redirect_to :controller => 'rb_master_backlogs', :action => 'show', :project_id => @project.identifier
  end

  def close_completed
    @project.close_completed_versions

    redirect_to :controller => 'rb_master_backlogs', :action => 'show', :project_id => @project
  end
  
  def close
    if @sprint.stories.open.any?
      flash[:error] = l(:error_cannot_close_sprint_with_open_stories)
    else
      @sprint.update_attributes({:status => 'closed'})
    end
    redirect_to :controller => 'rb_master_backlogs', :action => 'show', :project_id => @project
  end
 
end
