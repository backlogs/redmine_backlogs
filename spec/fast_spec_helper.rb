require 'config'

plugin_path = 'plugins/redmine_backlogs'
$:.push File.expand_path("#{plugin_path}/app/helpers")
$:.push File.expand_path("#{plugin_path}/app/models")
$:.push File.expand_path("#{plugin_path}/app/controllers")
$:.push File.expand_path("#{plugin_path}/lib")

