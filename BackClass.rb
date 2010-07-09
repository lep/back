#!/usr/bin/ruby

require 'find'
require 'inotify'

class Back

	def initialize(source, destination)
		@sync=[]
		@dir_watcher=Inotify.new
		@file_watcher=Inotify.new
		@dest_files=[]

		Find.find(source) do |f|
			@dir_watcher.add_watch(f, Inotify::CREATE | Inotify::ISDIR)
			@file_watcher.add_watch(f, Inotify::CREATE | Inotify::DELETE | Inotify::MODIFY | Inotify::MOVE)
		end
		
		Find.find(destination) do |f|
			@dest_files << f
		end

	end


end
