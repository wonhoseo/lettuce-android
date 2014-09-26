
require 'lettuce-android/adb_local_client'

module Lettuce module Android module Operations
    
  class Device < Lettuce::Android::Operations::AdbLocalClient
    #include Lettuce::Android::Operations::AdbLocalClient

    # @return [Device] a new Device instance 
    def initialize options={}
      init_logger()
      super options
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
