#!/usr/bin/ruby

require 'inotify'
require 'find'

def startInotify(w)
	t = Thread.new(w) do |watcher|
		watcher.each_event do |event|
			puts event.name 
			puts event.mask
			puts event.wd
			puts event.inspect
		end
	end

	t.join
end


def initInotify()
	watcher=Inotify.new
	Find.find("/home/lep/test-i") do |f|
		watcher.add_watch(f, Inotify::CREATE | Inotify::DELETE | Inotify::MODIFY | Inotify::MOVED )
	end
	watcher
end

startInotify initInotify()
