include RbCommonHelper

class RbImpedimentsController < RbApplicationController
  unloadable

  def create
    params.permit!
    @settings = Backlogs.setting
    begin
      @impediment = RbTask.create_with_relationships(params, User.current.id, @project.id, true)
    rescue => e
      Rails.logger.error(e.message.blank? ? e.to_s : e.message)
      render :partial => "backlogs/model_errors", :object => { "base" => e.message.blank? ? e.to_s : e.message }, :status => 400
      return
    end

    result = @impediment.errors.size
    status = (result == 0 ? 200 : 400)
    @include_meta = true

    respond_to do |format|
      format.html { render :partial => "impediment", :object => @impediment, :status => status }
    end
  end

  def update
    params.permit!
    @impediment = RbTask.find_by_id(params[:id])
    @settings = Backlogs.setting
    begin
      result = @impediment.update_with_relationships(params)
    rescue => e
      render :text => e.message.blank? ? e.to_s : e.message, :status => 400
      return
    end
    status = (result ? 200 : 400)
    @include_meta = true

    respond_to do |format|
      format.html { render :partial => "impediment", :object => @impediment, :status => status }
    end
  end

end
