#!/usr/bin/env ruby

require 'pathname'
require 'fileutils'

FileUtils.chdir(Pathname.new($0).dirname)

list = %x{egrep '(plugin|origin|commit)' plugin.versions | awk '{print $2}'}
list = list.split("\n")

unless list.length % 3 == 0 then
  puts list
  puts "Error in plugin.versions format #{list.length}, #{list.length % 3}"
  exit -1
end
cnt = 0
@h = Hash.new
while cnt < list.length
  a = list.slice(cnt,3)
  cnt = cnt + 3
  @h[a[0]] = a[1,2]
end
# puts @h.inspect 
# h = Hash[*list.split("\n")]

for d, g in @h do
  # puts g.inspect
 cmd = "git clone #{g.first} #{d}"
 cmd_co = "git checkout #{g.last} .;  git reset --hard #{g.last}; git clean -f"
 if File.exist?("#{d}/.git") then
   puts "skipping ... #{cmd}"
 else
   puts "running  ... #{cmd};cd #{d};#{cmd_co}"
   %x{#{cmd}} 
   FileUtils.chdir(d) 
   %x{#{cmd_co}}
   FileUtils.chdir( '..')
   # %x{#{cmd};cd #{d};#{cmd_co}}
 end
end
# puts %x{git checkout .}

