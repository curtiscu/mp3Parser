#!/usr/bin/env ruby

require 'rubygems'  
require 'active_record'  
require 'id3lib'
require 'pathname'
require 'find' 
require 'fileutils' 
require 'optparse'


ActiveRecord::Base.establish_connection(
    :adapter => "sqlite",
    :database  => "db/development.sqlite3"
  )


=begin
  FIELD LIST IN 'SONGS' TABLE
  artist:string 
  album:string
  title:string
  track:integer
  time:string
  genre:string
=end

class Songs < ActiveRecord::Base  
  
  # TODO: some way to dynamically dump field list?
  
end



class CurtisMP3Parser

attr_accessor :mp3_count, :file_count, :dir_count, :problem_dirs

def initialize
  @mp3_count = 0
  @file_count = 0 
  @dir_count = 0
  @problem_dirs = Array.new
end

def process_mp3 (  mp3_file )

  #puts "hit: " + mp3_file
  
=begin

  # dumps ID3 tag info to screen. ultimately write to DB
  tag = ID3Lib::Tag.new(mp3_file)
  puts "track #: " + tag.track 
  puts "title: " + tag.title
  puts "album: " + tag.album
  puts "artist: " + tag.artist
  genreNumber =  tag.genre.scan(/\d+/) # parse as returns genre like "(17)", with '(' and ')'
  puts "genre: " + ID3Lib::Info::Genres[genreNumber[0].to_i]
  

  # interesting detailed stuff comes form this  
  puts "\ndumping frames"
  tag.each do |frame|
       p frame
     end
   
  puts "\ndumping info on frame ID TALB"
  puts ID3Lib::Info.frame(:TALB)
=end

  @mp3_count += 1
  
end

def prob_file ( p )
  puts "ERR >> " + p
  @problem_dirs.push p
end

def findmp3s ( f=nil )

  return if f.nil?
  
  p = Pathname(f)  
  string_name = nil
  if p.directory?
    @dir_count += 1
    puts "dir: " + p
    if !p.readable?
      prob_file p
      return
    end
    p.children.each { |file| 
      findmp3s file
    }
  else
    @file_count +=1
    
    # there's a subdir in my mp3 folder
    # entitled /mnt/gizmo/mp3/Curtis/Poncho Sanchez?
    # and it barfs unless I try skipping it like this
    if !p.exist? || p.symlink?
      prob_file p
      return
    end 
    
    string_name = p.realpath.to_s
    if !(string_name =~ /mp3$/)
      #puts "miss: " + string_name
    else
      process_mp3 string_name
    end
  end
  
end


end

# take subdir param
# load a file
# print ID3 to screen
# write to DB
# break ..
# dump all db records to screen



#command-line options
options = {}

optparse = OptionParser.new do|opts|
  # Set a banner, displayed at the top of the help screen.
  opts.banner = "Usage: mp3Parser.rb [options] file1 file2 ..."

  # Define the options, and what they do
  options[:verbose] = false
  opts.on( '-v', '--verbose', 'Output more information' ) do
    options[:verbose] = true
  end

  options[:root_dir] = nil
  opts.on( '-r', '--root', 'Root directory to search from.' ) do|file|
    options[:root_dir] = file
  end

  # displays the help screen, all programs assumed to have this option.
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
end

optparse.parse!


if options[:root_dir].nil? || options[:help]
  puts optparse
  return
else
  puts "Being verbose" if options[:verbose]

  p = CurtisMP3Parser.new    
  ARGV.each do|f|
    puts "Searching for mp3s in #{f}..."
    p.findmp3s f  # this kicks off the work 
  end
  
  puts "total dir(s) : " + p.dir_count.to_s
  puts "total file(s) : " + p.file_count.to_s
  puts "total mp3 file(s) : " + p.mp3_count.to_s
  puts "total non mp3 file(s) : " + (p.file_count - p.mp3_count).to_s
  if !p.problem_dirs.empty?
    puts "problem dir(s) .."
    p.problem_dirs.each { |path| puts "path : #{path}" }
  end
  
end

