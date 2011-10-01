require 'prawn'

include RbCommonHelper

class RbStoriesController < RbApplicationController
  unloadable
  include BacklogsCards
  
  def index
    cards = nil
    begin
      cards = Cards.new(params[:sprint_id] ? @sprint.stories : RbStory.product_backlog(@project), params[:sprint_id], current_language)
    rescue Prawn::Errors::CannotFit
      cards = nil
    end

    respond_to do |format|
      format.pdf {
        if cards
          send_data(cards.pdf.render, :disposition => 'attachment', :type => 'application/pdf')
        else
          render :text => "There was a problem rendering the cards. A possible error could be that the selected font exceeds a render box", :status => 500
        end
      }
    end
  end
  
  def create
    params['author_id'] = User.current.id
    begin
      story = RbStory.create_and_position(params)
    rescue => e
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    status = (story.id ? 200 : 400)
    
    respond_to do |format|
      format.html { render :partial => "story", :object => story, :status => status }
    end
  end

  def update
    story = RbStory.find(params[:id])
    YAML::dump(story)
    YAML::dump(params)
    begin
      result = story.update_and_position!(params)
    rescue => e
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end

    story.reload
    status = (result ? 200 : 400)
    
    respond_to do |format|
      format.html { render :partial => "story", :object => story, :status => status }
    end
  end

end
