#!/usr/bin/ruby

require 'rb-inotify'

notifier=INotify::Notifier.new

notifier.watch("/home/lep/test-i", :delete, :move_from, :recursive) do |event|
	puts "Delete #{event.name}"
end

notifier.watch("/home/lep/test-i", :create, :move_from, :modify, :recursive) do |event|
	puts "Created #{event.name}"
end
