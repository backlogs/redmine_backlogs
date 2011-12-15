module Backlogs
  def version
    root = File.expand_path('..', File.dirname(__FILE__))
    git = File.join(root, '.git')
    v = Redmine::Plugin.find(:redmine_backlogs).version

    g = nil
    if File.directory?(git)
      Dir.chdir(root)
      g = `git log | head -1 | awk '{print $2}'`
      g.strip!
      g = "(#{g})"
    end

    v = [v, g].compact.join(' ')
    v = '?' if v == ''
    return v
  end

  module_function :version
end
