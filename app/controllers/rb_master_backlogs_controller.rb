include RbCommonHelper

class RbMasterBacklogsController < RbApplicationController
  unloadable

  def show
    product_backlog_stories = Story.product_backlog(@project)
    
    
    sprints = Sprint.open_sprints(@project)
    #TIB (ajout des sprints fermés)
    c_sprints = Sprint.closed_sprints(@project)
    
    
    last_story = Story.find(
                          :first, 
                          :conditions => ["project_id=? AND tracker_id in (?)", @project, Story.trackers],
                          :order => "updated_on DESC"
                          )
    @last_update = (last_story ? last_story.updated_on : nil)
    @product_backlog = { :sprint => nil, :stories => product_backlog_stories }
    @sprint_backlogs = sprints.map{ |s| { :sprint => s, :stories => s.stories } }
    
    #TIB (ajout de @c_sprint_backlogs)
    @c_sprint_backlogs = c_sprints.map{|s| { :sprint => s, :stories => s.stories } }
    
    respond_to do |format|
      format.html { render :layout => "rb"}
    end
  end
  
end
