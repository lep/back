#!/usr/bin/ruby

class FQueue

	def initialize file_name, load_file=false
		@queue = []
		if load_file
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

end
