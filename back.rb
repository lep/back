#!/usr/bin/ruby

require 'inotify'
require 'find'

watcher = Inotify.new
descriptor_to_name=[]
basefiles=[]
actions= {
	Inotify::CREATE => :i_create,
	Inotify::DELETE => :i_delete,
	Inotify::MOVED_FROM => :i_delete,
	Inotify::MOVED_TO => :i_create,
	Inotify::MODIFY => :i_modify
}

Find.find("/home/lep/test-i") do |f|
	wd=watcher.add_watch(f, Inotify::CREATE | INOTIFY_DELETE | INOTIFY_MODIFY | INOTIFY_MOVED)
	descriptor_to_name[wd]=f
	basefiles << f
end

#brauch ich nen thread?
t=Thread.new do
	watcher.each_event do |event|
		action=actions[event.mask]
		if action
			send(action, event)
		end
	end
end

t.join
