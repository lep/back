#!/usr/bin/ruby

require 'inotify'
require 'find'
require 'fqueue'

class BackUp
	@@mask = Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY

	def initialize base_dir, backup_dir, interval
		@base_dir	= base_dir
		@backup_dir	= backup_dir
		@interval	= interval

		@wd2name	= {}
		#TODO: queue unique for each instance (filename)
		@queue		= FQueue.new '/home/lep/.backup_queue'
		@cookie_hash= {}

		@dir_watcher= Inotify.new
		self.add_base_watches

		@dir_thread	= Thread.new { self.watch }
		Thread.new { self.backup }

		@dir_thread.join
	end

	protected

	def backup
		while true
			sleep @interval
			self.process_queue
			self.link_files
		end
	end

	def process_queue
		#TODO: lock queue or something
		@queue.each do |e|
			#TODO: dispatch each action
		end
	end

	def link_files 
	end

	def add_base_watches
		Find.find @base_dir do |p|
			if not File.directory? p
				Find.prune
			else
				wd=@dir_watcher.add_watch(p, @@mask)
				@wd2name[wd]=path
			end
		end
	end

	def watch
		@dir_watcher.each_event do |ev|
			if ev.name != nil
				path=File.join(@wd2name[ev.wd], ev.name)
				file=path.clone
				file[0, @base_dir.length]=""
			end
			
			if ev.mask & Inotify::CREATE >0
				if ev.mask & Inotify::ISDIR >0
					wd=dir_watcher.add_watch(path, @@mask)
					@wd2name[wd]=path
					@queue << { :action => :create_dir, :path => file }
				else
					@queue << { :action => :create_file, :path => file }
				end
			elsif ev.mask & Inotify::DELETE >0
				@queue << {
					:action => ev.mask & Inotif::ISDIR >0 ?
						:delete_dir : 
						:delete_file,
					:path => file
				}
			elsif ev.mask & Inotify::MODIFY >0 and ev.mask & Inotify::ISDIR == 0
				@queue << { :action => :modify_file, :path => file }
			elsif ev.mask & Inotify::MOVED_FROM >0
				@cookie_hash[ev.cookie] = ev.cookie
				@queue << {
					:action => ev.mask & Inotif::ISDIR >0 ?
						:delete_dir :
						:delete_file,
					:path => file,
					:cookie => ev.cookie
				}
			elsif ev.mask & Inotify::MOVED_TO >0
				moved_from = @queue.select { |v| v[:cookie] == ev.cookie }.first
				@queue.delete moved_from

				if ev.mask & Inotify::ISDIR >0
					wd=@dir_watcher.add_watch(path, @@mask)
					@wd2name[wd]=path

					if @cookie_hash[ev.cookie] == ev.cookie
						@queue << {
							:action => :move_dir,
							:path => file,
							:from => moved_from[:path]
						}
					else #does not trigger~
						queue << { :action => :copy_dir, :path => file }
					end
				else
					 if @cookie_hash[ev.cookie] == ev.cookie
					 	@queue << {
							:action => :move_file,
							:path => file,
							:from => moved_from[:path]
						}
					 else #does not trigger too
					 	@queue << { :action => :copy_file, :path => file }
					 end
				end
			end

		
		end
	end


end


