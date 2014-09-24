# encoding: UTF-8

require 'lettuce-android/device'
require 'timeout'

module Lettuce module Android

  module Operations
    
    DEBUG = false
    
    VERSION_SDK_PROPERTY = 'ro.build.version.sdk'

    ADB_DEFAULT_PORT = 5555
    
    def log(message)
      $stdout.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} - #{message}" if ARGV.include? "-v" or ARGV.include? "--verbose" or DEBUG
    end
    
    def default_view_client
      @default_view_client
    end

    def dump
      default_view_client.dump
    end
    
    def wait_for_connection(options={})
      options[:timeout] ||= 60 # secs
      options[:verbose] ||= false
      #verbose = options[:verbose] || false
      options[:ignoresecuredevice] ||= false
      options[:serialno] ||= nil
      progname = File.basename($PROGRAM_NAME, File.extname($PROGRAM_NAME))
      if options[:serialno].nil?         
        options[:serialno] = ARGV.find { |arg| not(arg.start_with? "-") } || ENV['ANDROID_SERIAL'] || '.*'
      end
      ip_pattern = Regexp.compile("^(\d{1,3}\.){3}(\d{1,3})$")
      if ip_pattern.match(options[:serialno])
        options[:serialno] += ':%d' % ADB_DEFAULT_PORT 
      end
      if options[:verbose]
        $stderr.puts 'Connecting to a device with serialno=%s with a timeout of %d secs...' % [options[:serialno], options[:timeout]]
      end
      # timeout +5
      device = nil      
      begin 
        Timeout::timeout(options[:timeout] + 5) do 
          device = Device.new(options)           
        end
     rescue Timeout::Error
        $stderr.puts "can not connect to device"  
      end      
      if options[:verbose]
        $stderr.puts 'Connected to device with serialno=%s' % serialno
      end      
      secure = device.get_system_property('ro.secure')
      debuggable = device.get_system_property('ro.debuggable')
      version_property = device.get_property(VERSION_SDK_PROPERTY)
      version = version_property ?  version_property.to_i : -1
      if version == -1
        if options[:verbose]
          $stderr.puts "Couldn't obtain device SDK version"
        end
      end
      # we are going to use UiAutomator for versions >= 16 that's why we ignore if the device
      # is secure if this is true
      if secure == '1' and debuggable == '0' and not ignoresecuredevice and version < 16
        $stderr.puts "%s ERROR: Device is secure, it won't work" % progname
        if options[:verbose]
          $stderr.puts "    secure=%s debuggable=%s version=%d ignoresecuredevice=%s" % 
              [secure, debuggable, version, options[:ignoresecuredevice]]          
        end
        exit(2)
      end
      if options[:serialno].match(/[.*()+]/) and not options[:serialno].match(/(\d{1,3}\.){3}\d{1,3}/)
        #options[:serialno] = obtain_device_serail_number(device)
      end
      if options[:verbose]
        $stderr.puts 'Actual device serialno=%s' % options[:serialno]
      end
      return device, options[:serialno]
    end

    private
    def obtain_device_serail_number (device)
      serialno = device.get_property('ro.serialno')
      return serialno
    end
    
  end ## Operations

end end
