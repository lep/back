#!/usr/bin/ruby

require 'inotify'
require 'find'


wd2name = {}
queue = []
cookie_hash = {}
base_dir = '/home/lep/test-i/'
backup_dir = '/home/lep/test-b/'

Thread.new do
	while true
		sleep 30
		puts queue
		puts "-----------------------------"
		queue.clear
	end
end

dir_watcher=Inotify.new

dir_thread=Thread.new do
	dir_watcher.each_event do |ev|
		if ev.name!= nil
			path=File.join(wd2name[ev.wd], ev.name)
			file=path.clone
			file[0, base_dir.length]=""
		end
		if ev.mask & Inotify::CREATE>0
			if ev.mask & Inotify::ISDIR>0
				wd=dir_watcher.add_watch(path, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY)
				wd2name[wd]=path
				queue << { :action => :create_dir, :path => file}
			else
				queue << { :action => :create_file, :path => file }
			end
		elsif ev.mask & Inotify::DELETE>0
			if ev.mask & Inotify::ISDIR >0
				queue << { :action => :delete_dir, :path => file }
			else
				queue << { :action => :delete_file, :path => file }
			end
		elsif ev.mask & Inotify::MODIFY>0 and ev.mask & Inotify::ISDIR == 0
			queue << { :action =>:modify_file, :path => file }
		elsif ev.mask & Inotify::MOVED_FROM >0
			cookie_hash[ev.cookie]=ev.cookie
			if ev.mask & Inotify::ISDIR >0
				queue << {
					:action => :delete_dir, 
					:path => file, 
					:cookie => ev.cookie 
				}
			else
				queue << {
					:action => :delete_file,
					:path => file,
					:cookie => ev.cookie 
				}
			end
		elsif ev.mask & Inotify::MOVED_TO >0
			moved_from = queue.select { |v| v[:cookie] == ev.cookie }.first
			queue.delete moved_from
			if ev.mask & Inotify::ISDIR >0
				wd=dir_watcher.add_watch(path, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY)
				wd2name[wd]=path
				
				if cookie_hash[ev.cookie] == ev.cookie
					queue << {
						:action => :move_dir,
						:path => file, 
						:from =>moved_from[:path] 
					}
				else #does not trigger. but it should work with create + modify
					queue << { :action => :copy_dir, :path => file }
				end
			else
				if cookie_hash[ev.cookie] == ev.cookie
					queue << {
						:action => :move_file,
						:path => file, 
						:from =>moved_from[:delete_file]
					}
				else #does not trigger. :/
					queue << { :action => :copy_file, :path => file }
				end
			end
		end
	end
end

Find.find base_dir do |path|
	if !File.directory? path
		Find.prune
	else
		wd=dir_watcher.add_watch(path, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY)
		wd2name[wd]=path
	end

end

Find.find('/home/lep/test-b') do |path|
end


dir_thread.join
