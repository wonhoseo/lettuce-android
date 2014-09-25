#!/usr/bin/env ruby -wKU
# encoding: utf-8

require 'logger'
require 'nokogiri'

require 'lettuce-android/env'
require 'lettuce-android/view'
require 'lettuce-android/ui_automator_parser'

module Lettuce module Android module Operations
  class ViewClient
    
    DEBUG = true
    DEBUG_DEVICE = false
    DEBUG_RECEIVED = true
    # View server port
    VIEW_SERVER_PORT = 4939
    # version sdk property
    VERSION_SDK_PROPRETY = 'ro.build.version.sdk'
    VERSION_RELEASE_PROPERTY = 'ro.build.version.release'
    # class method
    
    USE_ADB_CLIENT_TO_GET_BUILD_PROPERTIES = true
    
    class << self
      
      
    end
    
    attr_reader :device
    attr_reader :serialno
    
    def initialize(device, serialno, options = {})
      init_logger()
      init_device(device)
      init_serialno(serialno)

      options = init_options(options)
      init_adb(options[:adb])
      @root = nil
      @view_by_id = {}
      init_display()
      init_build()
      init_ro()
      @force_view_server_use = options[:forceviewserveruse]
      @use_uiautomator = device.get_sdk_version() >= 16 and not options[:forceviewserveruse]
      if DEBUG
        logger.debug " init: use_ui_automator=#{@use_uiautomator}, sdk=#{@build[VERSION_SDK_PROPERTY]}, force_view_server_use=#{@force_view_server_use}"
      end
      # If UIAutomator is supported by the device it will be used
      @ignore_uiautomator_killed = options[:ignoreuiautomatorkilled]
      init_text_property()
      start_view_server(options[:startviewserver], options[:localport], options[:remoteport])
      
      #The list of windows as obtained by L{ViewClient.list()}
      @windows = nil
      
      if options[:autodump]
        dump()
      end  
    end
  
    def dump(window=-1,sleep_delay=1)
      if sleep_delay > 0
        sleep(sleep_delay)
      end
      
      if @use_uiautomator
        dump_with_uiautomator()
      else
        dump_with_view_server(window)
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
    
    TEXT_PROPERTY_UI_AUTOMATOR = 'text'
    TEXT_PROPERTY_API_10 = 'mText'
    TEXT_PROPERTY = 'text:mText'
    
    def init_text_property
      if @use_uiautomator
        @text_property = TEXT_PROPERTY_UI_AUTOMATOR
      else
        if @build[VERSION_SDK_PROPRETY] <= 10
          @text_property = TEXT_PROPERTY_API_10
        else
          @text_property = TEXT_PROPERTY
        end
      end
    end
    
    def start_view_server(enable_view_server, local_port, remote_port)
      unless @use_uiautomator
        if enable_view_server
          response1 = device.shell('service call window 3')
          unless service_response(response1)
            begin
              response2 = device.shell('service call window 1 i32 %d' % remote_port)
              assert_service_response(response2)
            rescue
              msg = 'Cannot start view server.' \
                'This only works on emulator and devices running developer versions.' \
                'Does hierarchyviewer work on your device?' \
                'See https://github.com/dtmilano/AndroidViewClient/wiki/Secure-mode\n' \
                'Device properties:' \
                "    ro.secure=#{@ro['secure']}" \
                "    ro.debuggable=#{@ro['debuggable']}"
              raise RuntimeError, msg
            end
          end
        end
        
        @local_port = local_port
        @remote_port = remote_port
        forward_cmd = "#{adb_command} -s #{@serialno} forward tcp:#{@local_port} tcp:#{@remote_port}"
        logger.debug forward_cmd
        logger.debug `#{forward_cmd}`
      end
    end

    def dump_with_uiautomator
      # Using /dev/tty this works even on devices with no sdcard
      received = device.shell('uiautomator dump /dev/tty >/dev/null')
      received_xml = assert_valid_ui_automator_dump(received)
      set_views_form_uiautomator(received_xml)
    end
    


    def assert_valid_ui_automator_dump(received)
      unless received
        raise RuntimeError, 'ERROR: Empty UiAutomator dump was received' 
      end
      if DEBUG
        @received = received
      end
      if DEBUG_RECEIVED
        logger.debug "received #{received.length} chars"
        logger.debug "\n#{received}\n"
      end
      if /[\n\S]*Killed[\n\r\S]*/m =~ received
        raise RuntimeError, "ERROR: UiAutomator output contains no valid information. UiAutomator was killed, no reason given."
      end
      if @ignore_uiautomator_killed
        if DEBUG_RECEIVED
          logger.debug "ignoring UiAutomator Killed"
        end
        killed_re = %r|</hierarchy>[\n\S]*Killed|m 
        if killed_re =~ received
          received.sub!(killed_re,'</hierarchy>')
        elsif DEBUG_RECEIVED
          logger.debug "UiAutomator Killed: NOT FOUND!"
        end
        dump_to_dev_tty_re = %r|</hierarchy>[\n\S]*UI hierchary dumped to: /dev/tty.*|m
        if dump_to_dev_tty_re =~ received
          received.sub!(dump_to_dev_tty_re, '</hierarchy>')
        end
        # API19 seems to send this warning as part of the XML.
        # Let's remove it if present
        received.sub!('WARNING: linker: libdvm.so has text relocations. This is wasting memory and is a security risk. Please fix.\r\n', '')
        if DEBUG_RECEIVED
          logger.debug "received=#{received}"
        end
      end
      if received.match(%r|\[: not found|)
        raise RuntimeError, "ERROR: Some emulator images (i.e. android 4.1.2 API 16 generic_x86) does not include the '[' command." \
          "While UiAutomator back-end might be supported 'uiautomator' command fails." \
          "You should force ViewServer back-end."
      end
      return received
    end

    def set_views_form_uiautomator(received)
      if received.nil? or received.empty?
        raise ArgumentError, "received is empty"
      end
      @views = []
      parser_tree_from_uiautomator_dump(received)
      if DEBUG
        logger.debug "there are #{@views.length} views in this dump"
      end
    end
    
    def parser_tree_from_uiautomator_dump received
      doc = UiAutomatorParser.new(@device, @build[VERSION_SDK_PROPERTY])
      parser = Nokogiri::XML::SAX::Parser.new(doc)
      parser.parse(received)
      @root = doc.root
      @views = doc.views
      @views_by_id = Hash[@views.collect{|view| [view.get_unique_id(), view]}]
    end
    
    def dump_with_view_server(window=-1)
      
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
