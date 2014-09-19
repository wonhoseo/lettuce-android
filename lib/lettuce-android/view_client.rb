# encoding: utf-8

class Lettuce::Android::ViewClient
  
  # View server port
  VIEW_SERVER_PORT = 4939
      
  # class method
  class << self
    
    
  end
  
  attr_reader :device, :serialno
  
  def initialize(device, serialno, options = {})
    unless device
      raise "Device is not connected"
    else
      @device = device
    end
    
    unless serialno
      raise ArguementError "serialno cannot be nil"
    else
      @serialno = serialno
    end
    
    if options[:autodump]
      dump()
    end  
  end

  def dump
    
  end

  private
  def init_options(options={})
    options[:adb] = options[:adb] || nil
    options[:autodump] = (not options[:autodump].nil?) ? options[:autodump] : true
    options[:forceviewserveruse] = options[:forceviewserveruse] || false
    options[:localport] ||= VIEW_SERVER_PORT
    options[:remoteport] ||= VIEW_SERVER_PORT
    options[:startviewserver] = (not options[:startviewserver].nil?) ? options[:startviewserver] : true
    options[:ignoreuiautomatorkilled] ||= false
    options
  end
  
end