require 'prawn'
require 'backlogs_printable_cards'

include RbCommonHelper

class RbStoriesController < RbApplicationController
  unloadable
  include BacklogsPrintableCards

  def index
    if ! BacklogsPrintableCards::CardPageLayout.selected
      render :text => "No label stock selected. How did you get here?", :status => 500
      return
    end

    begin
      cards = BacklogsPrintableCards::PrintableCards.new(params[:sprint_id] ? @sprint.stories : RbStory.product_backlog(@project), params[:sprint_id], current_language)
    rescue Prawn::Errors::CannotFit
      render :text => "There was a problem rendering the cards. A possible error could be that the selected font exceeds a render box", :status => 500
      return
    end

    respond_to do |format|
      format.pdf {
        send_data(cards.pdf.render, :disposition => 'attachment', :type => 'application/pdf')
      }
    end
  end

  def create

    # lft and rgt fields are handled by acts_as_nested_set
    attribs = params.select{|k,v| !['prev', 'next', 'id', 'lft', 'rgt'].include?(k) && RbStory.column_names.include?(k) }
    attribs[:author_id] = User.current.id
    attribs[:status] = RbStory.class_default_status
    attribs = attribs.to_enum.to_h
    story = RbStory.new(attribs)
    result = RbStory.save_and_position(story, params)

    respond_to do |format|
      format.html { render partial: "story", status: (result ? 200 : 400), locals: {story: story} }
    end
  end

  def update
    story = RbStory.find(params[:id])
    result = story.update_and_position(params)

    respond_to do |format|
      format.html { render partial: "story", status: (result ? 200 : 400), locals: {story: story} }
    end
  end

  def tooltip
    story = RbStory.find(params[:id])
    respond_to do |format|
      format.html { render :partial => "tooltip", :object => story }
    end
  end

end
