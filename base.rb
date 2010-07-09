#!/usr/bin/ruby

require 'inotify'
require 'find'


wd2name={}

dir_watcher=Inotify.new

dir_thread=Thread.new do
	dir_watcher.each_event do |ev|
		if ev.mask & Inotify::CREATE>0 and ev.mask & Inotify::ISDIR>0
			puts "Created"
			path=File.join(wd2name[ev.wd], ev.name)
			puts path
			puts ev.wd
			puts "--------------"
			wd=dir_watcher.add_watch(path, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY)
			wd2name[wd]=path
		elsif ev.mask & Inotify::DELETE>0# and ev.mask & Inotify::ISDIR>0
			puts "Delete #{wd2name[ev.wd]}/#{ev.name}"
		elsif ev.mask & Inotify::MODIFY>0 and ev.mask & Inotify::ISDIR == 0
#			puts "Modified #{ev.name}"
		elsif ev.mask & Inotify::MOVED_TO>0
			puts "Moved to"
			puts ev.name
			puts ev.wd
			puts wd2name[ev.wd]
			puts "-------------"
#			wd2name[ev.wd]=File.join(wd2name[ev.wd], ev.name)
			path=File.join(wd2name[ev.wd], ev.name)
			wd=dir_watcher.add_watch(path, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY)
			wd2name[wd]=path
			puts "Moved from"
#			wd2name.delete_if {|k, _| k==File.join(wd2name[ev.wd], ev.name)}
		end
	end
end

Find.find('/home/lep/test-i') do |path|
	if !File.directory? path
		Find.prune
	else
		wd=dir_watcher.add_watch(path, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY)
		wd2name[wd]=path
	end
end

dir_thread.join
