include RbCommonHelper

class RbStoriesController < RbApplicationController
  unloadable
  include BacklogsCards
  
  def index
    cards = Cards.new(current_language)
    
    if params[:sprint_id]
      @sprint.stories.each { |story| cards.add(story) }
    else
      Story.product_backlog(@project).each { |story| cards.add(story, false) }
    end
    
    respond_to do |format|
      format.pdf { send_data(cards.pdf.render, :disposition => 'attachment', :type => 'application/pdf') }
    end
  end
  
  def create
    params['author_id'] = User.current.id
    story = Story.create_and_position(params)
    status = (story.id ? 200 : 400)
    
    respond_to do |format|
      format.html { render :partial => "story", :object => story, :status => status }
    end
  end

  def update
    story = Story.find(params[:id])
    result = story.update_and_position!(params)
    story.reload
    status = (result ? 200 : 400)
    
    respond_to do |format|
      format.html { render :partial => "story", :object => story, :status => status }
    end
  end


  def transitions
    transitions = Hash.new
    @project.trackers.each do |tid|
      tracker = Tracker.find_by_id(tid)
      transitions[tracker.id] = Hash.new
      IssueStatus.find(:all, :order => "position ASC").each do |status|
        allowed = status.find_new_statuses_allowed_to(User.current.roles_for_project(@project), tracker)
        to = transitions[tracker.id]["from-#{status.id}"] = allowed << status
      end
    end
    respond_to do |format|
      format.json { render :json => transitions }
    end
  end
end
