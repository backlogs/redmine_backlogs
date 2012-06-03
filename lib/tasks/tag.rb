#!/usr/bin/env ruby

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

newversion[level] += 1
(level + 1).upto(2) {|l| newversion[l] = 0}

newversion = 'v' + newversion.collect{|p| p.to_s}.join('.')

code = nil
File.open('init.rb') do |f|
  code = f.read
end
code.gsub!(/version\s+'[^']+'/m, "version '#{newversion}'")
code.gsub!(/author\s+'[^']+'/m, "author \"#{authors}\"")
File.open('init.rb', 'w') do |f|
  f.write(code)
end
code = nil
`git add init.rb`
`git commit -m #{newversion}`
`git tag #{newversion}`
`git push`
`git push --tags`
