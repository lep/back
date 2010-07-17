#!/usr/bin/ruby

class FQueue

	def initialize file_name
		@queue = []
		@file_name = file_name
		if File.exists? file_name
			File.open(file_name).each do |line|
				@queue << Marshal.load(line)
			end
		end
		@file = File.new file_name, "a"
	end

	def each 
		@queue.each { |e| yield e }
	end

	def << value
		@queue << value
		@file.puts Marshal.dump(value)
	end

	def clear
		@queue.clear
		@file.close
		@file = File.new @file_name, "w"
	end
	
	def to_a
		@queue.clone
	end
end
