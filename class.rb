#!/usr/bin/ruby

require 'inotify'
require 'find'
require 'fqueue'
require 'ftools'

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
			puts "Doing backup, yeah"
			self.link_n_stuff
			puts "Finished link_n_stuff"
			self.process_queue
			puts "Finished process_queue"
			puts "Backup finished"
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
		puts @queue
		puts "oooooooooooooooooooooooooooooooo"
		@queue.each do |e|
			new_path = File.join @new, e[:path]
	        old_path = File.join @base_dir, e[:path]

			puts old_path
			puts new_path

<<IDEE
Zuerst alle create und modify befehle abarbeiten,
danach alle move und remove befehle.
IDEE

			if e[:action] == :create_dir
				system "mkdir '#{new_path}'"
				#Dir.mkdir new_path
			elsif e[:action] == :create_file
				#File.unlink new_path if File.exists? new_path
				#File.copy( old_path, new_path) if File.exists? old_path
				system "cp '#{old_path}' '#{new_path}'"
			elsif e[:action]==:delete_dir
				system("rm -rf '#{new_path}'")
				#Dir.unlink new_path
			elsif e[:action]==:delete_file
				system("rm '#{new_file}'")
				#File.unlink new_path
			elsif e[:action]==:modify_file
				#File.unlink(new_path) if File.exists? new_path
				system("cp '#{old_path}' '#{new_path}'")
				#if File.exists? old_path
				#File.copy(old_path, new_path) if File.exists? old_path
			elsif e[:action]== :move_dir
				d = File.join(@new, e[:from])
				system "mv '#{d}' '#{new_path}'"
				#File.rename File.join(@latest, e[:from]), new_path
			elsif e[:action]== :move_file
				system "cp '#{old_path}' '#{new_path}'"
				#File.rename File.join(@latest, e[:from]), new_path
			end

		end
		puts "---------------------------"
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


