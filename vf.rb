#!/usr/bin/ruby
require 'fileutils'
require 'yaml'
require 'getoptlong'

VF_VERSION="0.0.1"

HOME = File.expand_path('~')
VF_HOME = File.join(HOME, ".vf")
VF_REPO = File.join(VF_HOME, "vf.yml")
CURRENT_PATH = File.expand_path(".")

class VF
  attr_accessor :verbose
  attr_accessor :save
  attr_accessor :alias
  attr_accessor :list
  attr_accessor :remove
  
  def initialize
    @verbose = false
    @save = false
    @list = false
    @remove = false
    
    FileUtils.mkdir(VF_HOME) unless File.exist? VF_HOME
    if File.exist? VF_REPO
      @data = YAML.load(File.open VF_REPO)
    else
      @data = {}
    end  
  end
  
  def run( a )
    verbose "Current path : #{CURRENT_PATH}"
    
    if @list
      cmd = ""
      @data.each do |k, v|
        cmd << "echo '#{k} : #{v}';"
      end
      puts cmd
      return
    end
    
    if @save
      @data[a] = CURRENT_PATH
      File.open(VF_REPO, "w") { |file| file.puts(@data.to_yaml) }
      puts "echo 'Alias #{a} added!'"
      return
    end
        
    if @remove
      if @data[a]
        @data.delete(a)
        File.open(VF_REPO, "w") { |file| file.puts(@data.to_yaml) }
        puts "echo 'Alias #{a} removed!'"
      else
        puts "echo 'Alias #{a} does not exist!'"        
      end
      return
    end
    
    if @data[a]
      puts "cd #{@data[a]}"
    else
      a = "" if a.nil?
      if a == "-" or a == "" or File.exist? a
        puts "cd #{a}"
      else  
        puts "echo \"Don't know where is #{a}\""
      end
    end
  end
  
  def usage
    puts '
    echo "usage: vf [-V] [-h] [-v] [-s] alias";
    echo "-V, --verbose  Verbose mode";
    echo "-s, --save     Save current path to alias";
    echo "-r, --remove   Remove alias";
    echo "-l, --list     List alias";
    echo "-v, --version  Show version";
    echo "-h, --help     Show this usage message"
    '
  end
  
  def version
    puts "echo 'vf v#{VF_VERSION}, (c) 2011 Gregoire Lejeune <gregoire.lejeune@free.fr>'"
  end
  
  def verbose( s ) 
    puts s if @verbose
  end
end

# -- main --

oOpt = GetoptLong.new(
  ['--verbose', '-V', GetoptLong::NO_ARGUMENT],
  ['--help',    '-h', GetoptLong::NO_ARGUMENT],
  ['--save',    '-s', GetoptLong::NO_ARGUMENT],
  ['--remove',  '-r', GetoptLong::NO_ARGUMENT],
  ['--list',    '-l', GetoptLong::NO_ARGUMENT],
  ['--version', '-v', GetoptLong::NO_ARGUMENT]
)

vf = VF.new

begin
  oOpt.each_option do |xOpt, xValue|
    case xOpt
      when '--verbose'
        vf.verbose = true
      when '--save'
        vf.save = true
      when '--remove'
        vf.remove = true
      when '--list'
        vf.list = true
      when '--help'
        vf.usage( )
        exit
      when '--version'
        vf.version( )
        exit
    end
  end
rescue GetoptLong::InvalidOption => e
  vf.usage( )
  exit
end

vf.run ARGV[0]
