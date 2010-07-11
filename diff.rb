#!/usr/bin/ruby

files=['a', 'b', 'c', 'd/a', 'b/a']
modified=['a']
created_files=['e', 'f']
deleted_files=['d/a']
deleted_dirs=['d']
created_dirs=['g']

puts files - deleted_files
