#!/usr/bin/ruby
require 'fileutils'
require 'yaml'
require 'getoptlong'

VF_VERSION="0.0.1"

HOME = File.expand_path('~')
VF_HOME = File.join(HOME, ".vf")
VF_REPO = File.join(VF_HOME, "vf.yml")
VF_HISTORY = File.join(VF_HOME, "vf.history")
VF_CONFIGURATION = File.join(VF_HOME, "vf.conf")
CURRENT_PATH = File.expand_path(".")

class String
  def to_bool
    self.match(/(true|t|yes|y|1)$/i) != nil
  end
end

class Array
  def rotate
    push(shift)[-1]
  end
end

class Historize
  attr_accessor :max_size
  
  def initialize(max_size = 50)
    @max_size = max_size
    if File.exist? VF_HISTORY
      @history = YAML.load(File.open VF_HISTORY)
    else
      @history = []
    end
  end
  
  def <<(v)
    if size >= @max_size
      @history.rotate
      @history[-1] = v
    else
      @history << v
    end
  end
  
  def size
    @history.size
  end
  
  def [](n)
    @history[n]
  end
  
  def last(n = @max_size)
    n = size if n > size
    @history[-n, n]
  end
  
  def save
    File.open(VF_HISTORY, "w") { |file| file.puts(@history.to_yaml) }
  end
end

class Configuration
  def initialize
    @config = {
      :history_max_size => {
        :convert => :to_i,
        :value => 50
      },
      :history_display_size => {
        :convert => :to_i,
        :value => 10
      },
      :auto_find => {
        :convert => :to_bool,
        :value => false
      }
    }
    
    if File.exist? VF_CONFIGURATION
      @config = @config.merge(YAML.load(File.open VF_CONFIGURATION))
    end
  end
  
  def []=(k, v)
    if @config.keys.include?(k.to_sym)
      @config[k.to_sym][:value] = v.send(@config[k.to_sym][:convert])
      return true
    else
      return false
    end
  end
  
  def each(&b)
    @config.each do |k, v|
      yield(k, v[:value])
    end
  end
  
  def [](k)
    @config[k][:value]
  end
  
  def save
    File.open(VF_CONFIGURATION, "w") { |file| file.puts(@config.to_yaml) }
  end
end

class VF
  attr_accessor :verbose
  attr_accessor :save
  attr_accessor :alias
  attr_accessor :list
  attr_accessor :remove
  attr_accessor :find
  attr_accessor :history
  attr_accessor :config
  
  def initialize
    @verbose = false
    @save = false
    @list = false
    @remove = false
    @find = false
    @history = false
    
    @config = nil
    @commands = []
    
    FileUtils.mkdir(VF_HOME) unless File.exist? VF_HOME
    if File.exist? VF_REPO
      @data = YAML.load(File.open VF_REPO)
    else
      @data = {}
    end  
    
    @configuration = Configuration::new()
    @historize = Historize::new(@configuration[:history_max_size])
  end
  
  def run(a)
    play(a)
    puts @commands.join(";").gsub(/;{2,}/, ";")
    @historize.save
  end
  
  def play( a )
    verbose "Current path : #{CURRENT_PATH}"
    
    unless @config.nil?
      if @config == "show"
        echo "VF Configuration :"
        @configuration.each do |k, v|
          echo "  #{k} = #{v}"
        end
      else
        if @configuration[@config] = a
          echo "Config : #{@config} set to #{a}"
        else
          echo "Config : #{@config} is not a config option!"
        end
        @configuration.save
      end
      return
    end
    
    if @list
      @data.each do |k, v|
        echo "#{k} : #{v}"
      end
      return
    end
    
    if @history
      h = @historize.last((a.to_i>0) ? a.to_i : @configuration[:history_display_size])
      n = h.size
      h.each do |cmd|
        echo "#{n} : #{cmd}"
        n = n - 1
      end
      return
    end
    
    if @save
      @data[a] = CURRENT_PATH
      File.open(VF_REPO, "w") { |file| file.puts(@data.to_yaml) }
      echo "Alias #{a} added!"
      return
    end
        
    if @remove
      if @data[a]
        @data.delete(a)
        File.open(VF_REPO, "w") { |file| file.puts(@data.to_yaml) }
        echo "Alias #{a} removed!"
      else
        echo "Alias #{a} does not exist!"
      end
      return
    end
    
    if @data[a]
      cd @data[a]
    else
      a = "" if a.nil?
      if a == "-" or a == "" or File.exist? a
        cd a
      else
        if a[0].chr == "+"
          position = a.to_i * -1
          path = @historize[position]
          if path.nil?
            echo "This entry does not existe. See 'vf -H #{position*-1}'"
          else
            cd path
          end
        else
          find = nil
          if @find or @configuration[:auto_find]
            find = `ls -R . | grep -m1 /#{a}:`.gsub!(/:$/,'')
          end
        
          if find
            cd find
          else
            echo "Don't know where is #{a}"
          end
        end
      end
    end
  end
  
  def usage()
    echo "usage: vf [option] value"
    echo "-V, --verbose                      : Verbose mode"
    echo "-s, --save                         : Save current path to alias"
    echo "-r, --remove                       : Remove alias"
    echo "-l, --list                         : List alias"
    echo "-f, --find                         : Try to find the directory"
    echo "-H, --history                      : Display history"
    echo "-c, --config show|<option> <value> : Show or set configuration"
    echo "-v, --version                      : Show version"
    echo "-h, --help                         : Show this usage message"
    puts @commands.join(";").gsub(/;{2,}/, ";")
  end
  
  def version
    echo "vf v#{VF_VERSION}, (c) 2011 Gregoire Lejeune <gregoire.lejeune@free.fr>"
    puts @commands.join(";").gsub(/;{2,}/, ";")
  end
  
  def verbose( s ) 
    echo "==> #{s}" if @verbose
  end
  
  private
  def add_command(c)
    @commands << c
  end
  
  def echo(data)
    add_command "echo \"#{data}\""
  end
  
  def cd(path)
    add_command "cd #{normalize(path)}"
    
    path = "~" if path == ""
    path = @historize[-2] if path == "-"
    path = File.expand_path(File.join(CURRENT_PATH, path))  unless path[0].chr == "/" or path[0].chr == "~"
    @historize << path
  end
  
  def normalize( path )
    path.gsub(" ", "\\ ")
  end
end

# -- main --

oOpt = GetoptLong.new(
  ['--verbose', '-V', GetoptLong::NO_ARGUMENT],
  ['--help',    '-h', GetoptLong::NO_ARGUMENT],
  ['--save',    '-s', GetoptLong::NO_ARGUMENT],
  ['--remove',  '-r', GetoptLong::NO_ARGUMENT],
  ['--list',    '-l', GetoptLong::NO_ARGUMENT],
  ['--find',    '-f', GetoptLong::NO_ARGUMENT],
  ['--history', '-H', GetoptLong::NO_ARGUMENT],
  ['--config',  '-c', GetoptLong::REQUIRED_ARGUMENT],
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
      when '--history'
        vf.history = true
      when '--config'
        vf.config = xValue
      when '--find'
        vf.find = true
      when '--help'
        vf.usage( )
        exit
      when '--version'
        vf.version( )
        exit
    end
  end
rescue GetoptLong::MissingArgument => e
  vf.usage
  exit
rescue GetoptLong::InvalidOption => e
  vf.usage
  exit
end

vf.run( ARGV[0] )
