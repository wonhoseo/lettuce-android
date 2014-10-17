# encoding:utf-8

require 'net/http'

require 'lettuce-android/device_actions'
require 'lettuce-android/device_matchers'
require 'lettuce-android/adb_local_client'
require 'logger'

module Lettuce module Android

  class Device < Lettuce::Android::AdbLocalClient

    include Lettuce::Android::DeviceActions
    include Lettuce::Android::DeviceMatchers

    ServerTimeoutError = Class.new(Timeout::Error)
    ActionFailedError = Class.new(RuntimeError)

    attr_reader :lettuce_server_port

    def initialize(serialno,options={})
      init_logger()
      super(serialno,options)

      @lettuce_server_port = Lettuce::Android::Operations.config.obtain_new_port
      #start_lettuce_server#TODO ??? adb forward tcp:7120 tcp:7120 
    end

    def using_timeout timeout
      old_timeout = Lettuce::Android::Operations.config.timeout
      Honeydew.config.timeout = timeout
      yield
    ensure
      Honeydew.config.timeout = old_timeout
    end

    def self.instance(serialno = ".*", options = {})
      @@instance ||= new(serialno, options)
    end

    def logger
      @logger_
    end

    private

    def perform_assertion action, arguments = {}, options = {}
      perform_action action, arguments, options
    rescue ActionFailedError
      false
    end

    def perform_action action, arguments = {}, options = {}
      ensure_device_ready
      arguments[:timeout] = Honeydew.config.timeout.to_s
      debug "performing action #{action} with arguments #{arguments}"
      send_command action, arguments
    end

    def send_command action, arguments
      uri = device_endpoint('/command')

      request = Net::HTTP::Post.new uri.path
      request.set_form_data action: action, arguments: arguments.to_json.to_s

      response = benchmark do
        Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.read_timeout = Honeydew.config.server_timeout
          response = http.request request
          {response: response, action: action}
        end
      end

      case response
      when Net::HTTPOK
        info "action succeeded, response: #{response.body}"
        response.body
      when Net::HTTPNoContent
        info "action failed, response: #{response.body}"
        raise ActionFailedError.new "Action #{action} called with arguments #{arguments.inspect} failed"
      else
        raise "honeydew-server failed to process command, response: #{response.body}"
      end
    end

    def benchmark
      result = nil
      realtime = Benchmark.realtime do
        result = yield
      end
      debug "action '#{result[:action]}' completed in #{(realtime * 1000).to_i}ms"
      result[:response]
    end

    def ensure_device_ready
      @device_ready ||= begin
        wait_for_honeydew_server
        true
      end
    end

    def wait_for_honeydew_server
      info 'waiting for honeydew-server to respond'
      Timeout.timeout(Honeydew.config.server_timeout.to_i, ServerTimeoutError) do
        Kernel.sleep 0.1 until honeydew_server_alive?
      end
      info 'honeydew-server is alive and awaiting commands'

    rescue ServerTimeoutError
      raise 'timed out waiting for honeydew-server to respond'
    end

    def honeydew_server_alive?
      Net::HTTP.get_response(device_endpoint('/status')).is_a?(Net::HTTPSuccess)
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENETRESET, EOFError
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
