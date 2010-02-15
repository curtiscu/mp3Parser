#!/usr/bin/env ruby

require 'rubygems'  
require 'active_record'  
require 'id3lib'
require 'pathname'
require 'find' 
require 'fileutils' 
require 'optparse'
require 'yaml'
require 'song'

dbconfig = YAML::load(File.open('config/db.yml'))
ActiveRecord::Base.establish_connection(dbconfig)

=begin
# changed as now using MySQL db
# establish connection to sqlite3 disk db
ActiveRecord::Base.establish_connection(
    :adapter => "sqlite",
    :database  => "db/development.sqlite3"
  )
=end


class CurtisMP3Parser

  attr_accessor :mp3_count, :file_count, :dir_count, :skip_dirs
  @options = {}
  
  def initialize ( options )
  
    @options = options
    
    # these gather useful stats to print
    # out when program complete
    @mp3_count = 0
    @file_count = 0 
    @dir_count = 0
    @skip_dirs = Array.new
    @skip_files = Array.new
  end
  
  def process_mp3 (  mp3_file )
      
    tag = ID3Lib::Tag.new(mp3_file)
    
    if @options[:debug]
      # full dump of mp3 frame info from tag
      puts "\ndumping frames"
      tag.each do |frame|
           p frame
         end
    end
  
    # set vars to write to db
    t_path = mp3_file
    t_track = tag.track.nil? ? "" : tag.track
    t_title = tag.title.nil? ? "" : tag.title
    t_album = tag.album.nil? ? "" : tag.album
    t_artist = tag.artist.nil? ? "" : tag.artist
    t_genre = tag.genre.nil? ? "" : tag.genre
    
    # for some reason they thought it was a good idea 
    # to return genre like "(17)", i.e. inside '(' and ')'
    # parse out genre number
    if !t_genre.empty?
      genreNumber =  t_genre.scan(/\d+/) 
      t_genre = ID3Lib::Info::Genres[genreNumber[0].to_i]
    end
    
    if @options[:debug]
      # debug dump ID3 tag info to display.
      puts "track #: " + t_track 
      puts "title: " + t_title
      puts "album: " + t_album
      puts "artist: " + t_artist
      puts "genre: " + t_genre
      puts "path: " + t_path
    end
    
    if @options[:do_nothing]
      puts "adding (not): " + mp3_file  if @options[:verbose]
    else
      puts "adding: " + mp3_file if @options[:verbose]
      Song.create(:artist => t_artist, 
        :album => t_album, 
        :title => t_title, 
        :track => t_track, 
        :genre => t_genre,
        :path => t_path)
    end
    
    @mp3_count += 1
    
  end
  
  def skip_file ( f )
    puts "ERR file >> " + f  if @options[:verbose]
    @skip_files.push f
  end
  
  def skip_dir ( d )
    puts "ERR dir >> " + d if @options[:verbose]
    @skip_dirs.push d
  end
  
  def findmp3s ( f=nil )
  
    return if f.nil?
    
    p = Pathname(f)  
    string_name = nil
    if p.directory?
      @dir_count += 1
      if @options[:quiet]
        print "."
      else
        puts "process dir: " + p 
      end 
      
      if !p.readable?
        skip_dir p
        return
      end
      p.children.each { |file| 
        findmp3s file
      } if @options[:recursive]
    else
      @file_count +=1
      
      # there's a subdir in my mp3 folder
      # entitled /mnt/gizmo/mp3/Curtis/Poncho Sanchez?
      # and it barfs unless I try skipping it like this
      if !p.exist? || p.symlink?
        skip_file p
        return
      end 
      
      string_name = p.basename.to_s
      if !(string_name =~ /^[^.].*mp3$/) 
        skip_file p
      else
        process_mp3 p.realpath.to_s
      end
    end
    
  end
  
  def db_test
    s = Song.find(:all)
    s.each do  |song| 
      puts "song name in DB: " + song.artist
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
  
  options[:recursive] = false
  opts.on( '-r', '--recursive', 'Recursive directory search' ) do
    options[:recursive] = true
  end
  
  options[:quiet] = false
  opts.on( '-q', '--quiet', 'Output less information' ) do
    options[:quiet] = true
  end  
  
  options[:debug] = false
  opts.on( '-d', '--debug', 'Output lots of debug information' ) do
    options[:debug] = true
  end  
    
  options[:do_nothing] = false
  opts.on( '-n', '--nothing', 'No changes to DB, print out what would be added.' ) do
    options[:do_nothing] = true
  end


  # displays the help screen, all programs assumed to have this option.
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end
  
  # displays the help screen, all programs assumed to have this option.
  options[:test] = false
  opts.on( '-t', '--test', 'pull first record from DB' ) do
    options[:test] = true
  end


end

optparse.parse!

p = CurtisMP3Parser.new(options)

if options[:test] 
  p.db_test
  return
end  


if ARGV.empty? || options[:help]
  puts optparse
else
  puts "Being verbose" if options[:verbose]


    
  ARGV.each do|f|
    STDOUT.sync = true #forces no caching of 'print' statements.
    puts "Searching for mp3s in #{f}..."
    p.findmp3s f  # this kicks off the work 
  end
  
  puts "total dir(s) : " + p.dir_count.to_s
  puts "skipped dir(s) : " + p.skip_dirs.size.to_s
  puts "total file(s) : " + p.file_count.to_s
  puts "total mp3 file(s) : " + p.mp3_count.to_s
  puts "skipped file(s) : " + (p.file_count - p.mp3_count).to_s
  if p.skip_dirs.size > 0
    puts "problem dir(s) .."
    p.problem_dirs.each { |path| puts "path : #{path}" }
  end
  
end

