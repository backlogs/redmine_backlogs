include RbCommonHelper

class RbUpdatedItemsController < RbApplicationController
  unloadable

  # Returns all models that have changed since params[:since]
  # params[:only] limits the types of models that the method
  # should return
  def show
    @settings = Backlogs.settings
    only  = (params[:only] ? params[:only].split(/, ?/).map{|v| v.to_sym} : [:sprints, :stories, :tasks, :impediments])
    @items = HashWithIndifferentAccess.new
    @include_meta = true
    @last_update = nil

    latest_updates = []
    if only.include? :stories
      @items[:stories] = RbStory.find_all_updated_since(params[:since], @project.id)
      if @items[:stories].length > 0
        latest_updates << @items[:stories].sort{ |a,b| a.updated_on <=> b.updated_on }.last
      end
    end

    if only.include? :tasks
      @items[:tasks] = RbTask.find_all_updated_since(params[:since], @project.id, false, params[:sprint])
      if @items[:tasks].length > 0
        latest_updates << @items[:tasks].sort{ |a,b| a.updated_on <=> b.updated_on }.last
      end
    end

    if only.include? :impediments
      @items[:impediments] = RbTask.find_all_updated_since(params[:since], @project.id, true, params[:sprint])
      if @items[:impediments].length > 0
        latest_updates << @items[:impediments].sort{ |a,b| a.updated_on <=> b.updated_on }.last
      end
    end

    if latest_updates.length > 0
      @last_update = latest_updates.sort{ |a,b| a.updated_on <=> b.updated_on }.last.updated_on
    end

    respond_to do |format|
      format.html { render :layout => false }
    end
  end
end
