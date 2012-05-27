When /^I (post|put|get) the "(.+)" page$/ do |method,url|
  @url = url
  @request = { method => url }
  @method = method
end
When /^I (post|put|get) the "(.+)" page with params:$/ do |method,url,params|
  @url = url
  @request = { method => url }
  @method = method

  @params = params.transpose.hashes[0]
end
When /^I (post|put|get) the "(.+)" page using format "(.+)"$/ do |method,url, format|
  @url = url
  @request = { method => url }
  @method = method

  @format = format
end

Then /^application should route me to:$/ do |controller|
  if Rails::VERSION::MAJOR >= 3
    @routes = Rails.application.routes # workaround for assert_recognizes bug
  end
  controller = controller.transpose
  # convert headers to symbols
  controller.map_headers! { |header| header.to_sym }
  controller_with_params = controller.hashes[0]
  @request.should route_to controller_with_params
  controller_with_params[:format] = @format if @format
  controller_with_params.merge!(@params) if @params
  url = url_for(controller_with_params)
  if @method == 'put'
    put url, controller_with_params
  else
    post url, controller_with_params
  end
end

