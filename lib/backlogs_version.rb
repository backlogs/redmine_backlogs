module Backlogs
  def version
    root = File.expand_path('..', File.dirname(__FILE__))
    git = File.join(root, '.git')
    changelog = File.join(root, 'CHANGELOG')
    v = nil
    File.open(changelog).readlines.each do |l|
      m = l.match(/^== [0-9]{4}-[0-9]{2}-[0-9]{2}\s+v(.+)/)
      next unless m
      v = m[1]
      break
    end

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
