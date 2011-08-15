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
      format.html { render :partial => "sprint", :status => status }
    end
  end

  def update
    attribs = params.select{|k,v| k != 'id' and RbSprint.column_names.include? k }
    attribs = Hash[*attribs.flatten]
    begin
      result  = @sprint.update_attributes attribs
    rescue => e
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    respond_to do |format|
      format.html { render :partial => "sprint", :status => (result ? 200 : 400) }
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
      bd.delete(:status)
      bd.keys.sort{|a, b| l("label_#{a}") <=> l("label_#{b}")}.each{ |k|
        label = l("label_#{k}")
        label = {:value => label, :comment => k.to_s} if [:points, :points_accepted].include?(k)
        ws << [nil, nil, nil, nil, label ] + bd[k]
      }
      s.tasks.each {|t|
        ws << [nil, nil, t.tracker.name, t.id, {:value => t.subject, :style => bold}] + t.burndown[:hours]
      }
    }

    send_data(dump.to_xml, :disposition => 'attachment', :type => 'application/vnd.ms-exce', :filename => "#{@project.identifier}-#{@sprint.name.gsub(/[^a-z0-9]/i, '')}.xml")
  end
  
end
