#!/usr/bin/ruby

$stdout = File.new('/dev/null', 'w')

require 'inotify'
require 'find'
require 'fqueue'
#require 'ftools'

class BackUp
	@@mask = Inotify::CREATE | Inotify::DELETE | Inotify::MOVE | Inotify::MODIFY

	def initialize base_dir, backup_dir, interval
		@base_dir	= base_dir
		@backup_dir	= backup_dir
		@interval	= interval

		@wd2name	= {}
		@queue		= [] # FQueue.new File.join(@backup_dir, '.backup_queue')
		@cookie_hash= {}

		self.initial_backup

		@dir_watcher= Inotify.new
		self.add_base_watches

		@dir_thread	= Thread.new { self.watch }
		Thread.new { self.backup }

		@dir_thread.join
	end

	protected

	def initial_backup
		return if File.exists? File.join(@backup_dir, 'latest')
		
		Find.find @base_dir do |f|
			if File.directory? f
			end

		end
	end

	def backup
		while true
			sleep @interval
			self.link_n_stuff
			self.process_queue
		end
	end

	def link_n_stuff
		latest_link = File.join(@backup_dir, 'latest')
		@new = File.join(@backup_dir, Time.now.strftime("%Y.%m.%d-%H:%M:%S"))
		latest = File.readlink(latest_link)
		
		Find.find( latest) do |f|
			name=f.clone
			name[0, latest.length]=""

			if File.directory? f
				Dir.mkdir File.join(@new, name)
			else
				File.link f, File.join(@new, name)
			end
		end
		
		File.unlink latest_link
		File.symlink @new, latest_link
	end

	def process_queue
		@queue.each do |e|
			new_path = File.join @new, e[:path]
	        old_path = File.join @base_dir, e[:path]
			case e[:action]
			when :create_dir then
				`mkdir '#{new_path}'` unless File.exists? new_path
			when :create_file then
				`cp '#{old_path}' '#{new_path}'`
			when :delete_dir then
				`rm -rf '#{new_path}'` if File.exists? new_path
			when :delete_file then
				File.unlink new_path if File.exists? new_path
			when :modify_file then
				`cp '#{old_path}' '#{new_path}'` if File.exists? old_path
			when :move_dir then
				d = File.join(@new, e[:from])
				`mv '#{d}' '#{new_path}'` if File.exists? d
			when :move_file then
				d = File.join(@new, e[:from])
				`cp '#{old_path}' '#{new_path}'` if File.exists? old_path
				`rm -f '#{d}'` if File.exists? d
			end
		end
		@queue.clear
	end

	def add_base_watches
		Find.find @base_dir do |p|
			if not File.directory? p
				Find.prune
			else
				wd=@dir_watcher.add_watch(p, @@mask)
				@wd2name[wd]=p
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
					wd=@dir_watcher.add_watch(path, @@mask)
					@wd2name[wd]=path
					@queue << { :action => :create_dir, :path => file }
					Find.find path do |f|
						if File.directory? f
							name=f.clone
							name[0, @base_dir.length]=""
							wd=@dir_watcher.add_watch(f, @@mask)
							@wd2name[wd]=f
							@queue << { :action => :create_dir, :path => name }
						end
					end
				else
					@queue << { :action => :create_file, :path => file }
				end
			elsif ev.mask & Inotify::DELETE >0
				@queue << {
					:action => ev.mask & Inotify::ISDIR >0 ?
						:delete_dir : 
						:delete_file,
					:path => file
				}
			elsif ev.mask & Inotify::MODIFY >0 and ev.mask & Inotify::ISDIR == 0
				@queue << { :action => :modify_file, :path => file }
			elsif ev.mask & Inotify::MOVED_FROM >0
				@cookie_hash[ev.cookie] = ev.cookie
				@queue << {
					:action => ev.mask & Inotify::ISDIR >0 ?
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


