#!/usr/bin/env ruby

require 'yaml'

tag = true

supported = {
  :redmine      => [
    {:version => '1.4', :ruby => '1.8.7'},
    {:version => '2.0', :ruby => '1.8.7'},
    {:version => '1.4', :ruby => '1.9.3'},
    {:version => '2.0', :ruby => '1.9.3'},
    {:version => '1.4', :ruby => '1.9', :unsupported => true},
    {:version => '2.0', :ruby => '1.9', :unsupported => true},
  ],
  :chiliproject => [
    {:version => '3.1.0', :ruby => '1.8.7'}
    ],
  }
  
`git fetch --tags`
  
tags = `git tag`.split("\n")
  
versions = {}
  
tags.each {|version|
  m = version.match(/^v([0-9]+)\.([0-9]+)\.([0-9]+)$/)
  raise "Unexpected version #{version.inspect}" unless m
  parts = 1.upto(3).collect{|i| Integer(m[i])}
  key = parts.collect{|p| p.to_s.rjust(5, '0')}.join('.')
  versions[key] = {:string => version, :parts => parts}

  `git tag -d #{version}`
  #`git push origin :refs/tags/#{version}`
}
  
newversion = versions[versions.keys.sort[-1]][:parts]

if tag
  if ARGV[0].nil?
    level = 2
  else
    level = Integer(ARGV[0])
    raise "Unexpected level #{ARGV[0]}" if level < 0 || level > 2
  end
  
  blame = {}
  `git ls-files`.split("\n").reject{|f| f =~ /\/jquery\// || f =~ /\.(gif|png|ttf|glabels)$/i}.each{|f|
    `git blame #{f}`.split("\n").each{|line|
      m = line.match(/\(([^)]+)[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [-+ 0-9]+\)/)
      name = m[1].strip.gsub(/"/, "'")
  
      next if name == ''
      blame[name] ||= 0
      blame[name] += 1
    }
  }
  
  authors = blame.keys.sort{|a, b| blame[b] <=> blame[a]}[0,7].join(',')
  
  newversion[level] += 1
  (level + 1).upto(2) {|l| newversion[l] = 0}
  
  newversion = 'v' + newversion.collect{|p| p.to_s}.join('.')
  
  supported[:backlogs] = newversion
  
  File.open('lib/versions.yml', 'w') {|f| f.write(supported.to_yaml)}
  
  code = nil
  File.open('init.rb') do |f|
    code = f.read
  end
  code.gsub!(/version\s+'[^']+'/m, "version '#{newversion}'")
  code.gsub!(/author\s+'[^']+'/m, "author \"#{authors}\"")
  File.open('init.rb', 'w') do |f|
    f.write(code)
  end
  `git add init.rb lib/versions.yml`
  `git commit -m #{newversion}`
  `git tag #{newversion}`
  `git push`
  `git push --tags`
end

Dir.chdir('../www')
`git pull`

File.open('versions.yml', 'w') {|f| f.write(supported.to_yaml)}
File.open('_includes/version.html', 'w') { |f| f.write(newversion) }
File.open('_includes/supported.html', 'w') do |f|
  s = supported.dup
  s[:chiliproject].each{|v| v[:platform] = 'CP' }
  s[:redmine].each{|v| v[:platform] = 'RM' }
  s = (s[:redmine] + s[:chiliproject])
  s = s.reject{|v| v[:unsupported]} + s.select{|v| v[:unsupported]}
  while s.size > 0
    f.write('<tr>')
    3.times do 
      v = s.shift
      if v
        f.write("<td>#{v[:platform]}#{v[:version]}/#{v[:ruby]}#{v[:unsupported] ? ' (unsupported)' : ''}</td>")
      else
        f.write("<td>&nbsp;</td>")
      end
    end
    f.write("</tr>\n")
  end
end

`git add versions.yml _includes/supported.html _includes/version.html`
`git commit -m #{newversion}`
`git push`
