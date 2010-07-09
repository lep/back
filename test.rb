#!/usr/bin/ruby

require 'inotify'
require 'find'


w=Inotify.new
l=Inotify.new
wd2name={}

Find.find("/home/lep/test-i") do |f|
	wd=l.add_watch(f, Inotify::CREATE | Inotify::ISDIR)
	wd2name[wd]=f
end

lt=Thread.new do
	l.each_event do |e|
		puts e.name
		puts e.mask
		puts e.wd
		puts e.
		p=File.join("/home/lep/test-i", e.name)
		wd=l.add_watch(p, Inotify::CREATE | Inotify::ISDIR)
		puts "Create dir #{p}"
	end
end

lt.join
