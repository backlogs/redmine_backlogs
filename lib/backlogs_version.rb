module Backlogs
  def version
    root = File.expand_path('..', File.dirname(__FILE__))
    git = File.join(root, '.git')
    changelog = File.join(root, 'CHANGELOG')
    v = nil
    if File.directory?(git)
      Dir.chdir(root)
      v = `git log | head -1 | awk '{print $2}'`
      v.strip!
      v = "git: #{v}"
    else
      File.open(changelog).readlines.each do |l|
        m = l.match(/^== [0-9]{4}-[0-9]{2}-[0-9]{2}\s+v(.+)/)
        next unless m
        v = m[1]
        break
      end
    end
    return v
  end

  module_function :version
end
