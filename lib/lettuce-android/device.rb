# encoding:utf-8

require 'lettuce-android/adb_local_client'
require 'logger'

module Lettuce module Android
    
  class Device < Lettuce::Android::AdbLocalClient

    # @return [Device] a new Device instance 
    def initialize(serialno,options={})
      init_logger()
      super(serialno,options)
    end

    def self.instance(serialno = nil, options = {})
      @@instance ||= new(serialno, options)
    end

    def logger
      @logger_
    end

    # define method debug warn info ....
    Logger::Severity.constants.each do |severity|
      severity_sym = severity.to_s.downcase.to_sym
      define_method severity_sym do |message|
        @logger_.__send__(severity_sym, "Device #{serialno}: #{message}")
      end
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

end end
