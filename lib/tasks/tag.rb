#!/usr/bin/env ruby

if ARGV[0].nil?
  level = 2
else
  level = Integer(ARGV[0])
  raise "Unexpected level #{ARGV[0]}" if level < 0 || level > 2
end

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
  `git push origin :refs/tags/#{version}`
}

newversion = versions[versions.keys.sort[-1]][:parts]

newversion[level] += 1
(level + 1).upto(2) {|l| newversion[l] = 0}

newversion = 'v' + newversion.collect{|p| p.to_s}.join('.')

`git tag #{newversion}`
`git push --tags`
