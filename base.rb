#!/usr/bin/ruby

require 'inotify'
require 'find'


wd2name={}

deleted_files=[]
deleted_dirs=[]
created_files=[]
created_dirs=[]
modified_files=[]

all_files_i=[]
all_files_b=[]

queue = []
cookie_hash={}

Thread.new do
	while true
		sleep 30
	#puts "Deleted files #{deleted_files}"
	#puts "Deleted dirs #{deleted_dirs}"
	#puts "Created files #{created_files}"
	#puts "Created dirs #{created_dirs}"
	#puts "Modified files #{modified_dirs}"
	#puts "All files from a #{all_files_i}"
	#puts "All files in backup #{all_files_b}"
		puts queue
		puts "-----------------------------"
		queue.clear
	end
end

dir_watcher=Inotify.new

dir_thread=Thread.new do
	dir_watcher.each_event do |ev|
		if ev.name!= nil
			path=File.join(wd2name[ev.wd], ev.name) #TODO: remove base dir
		end
		if ev.mask & Inotify::CREATE>0
			if ev.mask & Inotify::ISDIR>0
				wd=dir_watcher.add_watch(path, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY)
				wd2name[wd]=path
				created_dirs << path
				queue << { :create_dir => path }
			else
				queue << { :create_file => path }
				created_files << path 
			end
		elsif ev.mask & Inotify::DELETE>0
			if ev.mask & Inotify::ISDIR >0
				deleted_dirs << path
				queue << { :delete_dir => path }
			else
				deleted_files << path
				queue << { :delete_file => path }
			end
		elsif ev.mask & Inotify::MODIFY>0 and ev.mask & Inotify::ISDIR == 0
			modified_files << path
			queue << { :modify_file => path }
		elsif ev.mask & Inotify::MOVED_FROM >0
			cookie_hash[ev.cookie]=ev.cookie
			if ev.mask & Inotify::ISDIR >0
				deleted_dirs << path
				queue << { :delete_dir => path, :cookie => ev.cookie }
			else
				deleted_files << path
				queue << { :delete_file => path, :cookie => ev.cookie }
			end
		elsif ev.mask & Inotify::MOVED_TO >0
			moved_from = queue.select { |v| v[:cookie] == ev.cookie }.first
			queue.delete moved_from
			if ev.mask & Inotify::ISDIR >0
				wd=dir_watcher.add_watch(path, Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY)
				wd2name[wd]=path
				created_dirs << path
				
				if cookie_hash[ev.cookie] == ev.cookie
					queue << { :move_dir => path, :from =>moved_from[:delete_dir] }
				else
					queue << { :copy_dir => path }
				end
			else
				created_files << path
				if cookie_hash[ev.cookie] == ev.cookie
					queue << { :move_file => path, :from =>moved_from[:delete_file] }
				else
					queue << { :copy_file => path }
				end
			end
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
	all_files_i << path

end

Find.find('/home/lep/test-b') do |path|
	all_files_b << path
end


dir_thread.join
