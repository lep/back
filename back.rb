#!/usr/bin/ruby

require 'inotify'
require 'find'

watcher = Inotify.new
descriptor_to_name=[]
basefiles=[] #get from database
files_to_sync=[]
files_to_remove=[]

def i_delete (event)
    puts event.name
end

def i_create (event)
    puts event.name
end

actions= {
	Inotify::CREATE => :i_create,
	Inotify::DELETE => :i_delete,
	Inotify::MOVED_FROM => :i_delete,
	Inotify::MOVED_TO => :i_create,
	Inotify::MODIFY => :i_create
}

Find.find("/home/lep/test-i") do |f|
	#if File.directory?(f)
		wd=watcher.add_watch(f, Inotify::CREATE | Inotify::DELETE | Inotify::MODIFY | Inotify::MOVE)
		descriptor_to_name[wd]=f
	#end
	basefiles << f
	puts f
end

inotify_t=Thread.new do
	watcher.each_event do |event|
		action=actions[event.mask]
		if action
			send(action, event)
		end
	end
end

inotify_t.join

