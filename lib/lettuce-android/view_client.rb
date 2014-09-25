# encoding: utf-8

require 'logger'
require 'nokogiri'

require 'lettuce-android/env'
require 'lettuce-android/view'
require 'lettuce-android/ui_automator_parser'

module Lettuce module Android module Operations
  class ViewClient
    
    DEBUG_DEVICE = false
    
    # View server port
    VIEW_SERVER_PORT = 4939
    # version sdk property
    VERSION_SDK_PROPRETY = 'ro.build.version.sdk'
    VERSION_RELEASE_PROPERTY = 'ro.build.version.release'
    # class method
    
    USE_ADB_CLIENT_TO_GET_BUILD_PROPERTIES = true
    
    class << self
      
      
    end
    
    attr_reader :device, :serialno
    
    def initialize(device, serialno, options = {})
      init_logger()
      init_device(device)
      init_serialno(serialno)

      options = init_options(options)
      init_adb(options[:adb])
      init_display()
      init_build()
      init_ro()
      @use_ui_automator = device.get_sdk_version() >= 16 and not options[:forceviewserveruse]
      
      if options[:autodump]
        dump()
      end  
    end
  
    def dump(window=-1,sleep_delay=1)
      if sleep_delay > 0
        sleep(sleep_delay)
      end
      if @use_ui_automator
        dump_with_ui_automator()
      end
      
    end
  
    # 
    # private methods
    # 
    private
    def init_device device
      unless device
        raise "Device is not connected"
      else
        @device = device
      end      
    end
    
    def init_serialno serialno
      if serialno.nil?
        raise ArguementError "serialno cannot be nil"
      else
        @serialno = serialno
      end      
      if DEBUG_DEVICE
        logger.debug "ViewClient: using device with serialno:%s" % @serialno
      end
    end

    def init_options(options={})
      options[:adb] = options[:adb] || nil      
      options[:autodump] = options.has_key?(:autodump) ? options[:autodump] : true
      options[:forceviewserveruse] = options.has_key?(:forceviewserveruse) ? options[:forceviewserveruse] : false
      options[:localport] ||= VIEW_SERVER_PORT
      options[:remoteport] ||= VIEW_SERVER_PORT
      options[:startviewserver] = options.has_key?(:startviewserver) ? options[:startviewserver] : true
      options[:ignoreuiautomatorkilled] ||= false
      options
    end
    
    def init_adb(adb)
      if adb
        if not Pathname.executable?(adb)
          raise RuntimeError, "adb=#{adb} is not exectuable"
        end
      else
        adb = obtain_adb_path
      end
      @adb = adb
    end
    
    def obtain_adb_path
      Env.adb_path
    end
    
    def init_display
      # The map containing the device's display properties: width, height and density
      @display = {}
      for property in ['width', 'height', 'density']
        @display[property] = -1
        if USE_ADB_CLIENT_TO_GET_BUILD_PROPERTIES
          begin
            @display[property] = Integer device.get_property('display.'+property)
          rescue
            logger.warn "Couldn't determine display %s" % property
          end
        else
          #nothins    
        end
      end
    end

    def init_build
      @build = {}
      # The map containing the device's build properties: version.sdk, version.release
      for prop in [VERSION_SDK_PROPERTY, VERSION_RELEASE_PROPERTY]
        @build[prop] = -1
        begin
          if USE_ADB_CLIENT_TO_GET_BUILD_PROPERTIES
          @build[prop] = device.get_property(prop)
          else
          @build[prop] = device.shell('getprop ' + prop)               
          end
        rescue
          logger.warn "Couldn't determine build %s" % prop
        end
        if prop == VERSION_SDK_PROPERTY
          begin
            @build[prop] = Integer @build[prop]
          rescue ArgumentError
            @build[prop] = -1
          end
        end
      end
      return @build
    end
    
    def init_ro
      @ro = {}
      #The map containing the device's ro properties: secure, debuggable
      for property in ['secure', 'debuggable']        
        begin
          @display[property] = device.get_property('ro.'+property)
        rescue
          logger.warn "Couldn't determine ro %s" % property
          @display[property] = 'UNKNOWN'
        end
      end      
    end
    
    def dump_with_ui_automator
      received_xml = device.shell('uiautomator dump /dev/tty >/dev/null')
      parser = Nokogiri::XML::SAX::Parser.new(UiAutomatorParser.new(@device, @device.get_sdk_version()))
      parser.parse(received_xml)
    end
    def logger
      @logger_
    end

    private
    def init_logger
      log = Logger.new(STDOUT)
      log.progname = "Device"
      #log.datetime_format = "%Y-%m-%d %H:%M:%S.%L"
      log.datetime_format = "%m-%d %H:%M:%S.%6N"
      #log.formatter = proc do |severity, datetime, progname, msg|
      #  "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")},#{severity}, #{progname} - #{msg}\n"
      #end        
      # FATAL ERROR WARN INFO DEBUG
      #log.level = Logger::WARN
      log.level = Logger::DEBUG
      @logger_ = log 
    end    
  end
  
end end end
