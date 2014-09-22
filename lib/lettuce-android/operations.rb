# encoding: UTF-8

module Lettuce module Android

  module Operations
    
    DEBUG = false
    def log(message)
      $stdout.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} - #{message}" if ARGV.include? "-v" or ARGV.include? "--verbose" or DEBUG
    end
    
    def default_view_client
      @default_view_client
    end

    def dump
      default_view_client.dump
    end
    
    def wait_for_connection
      Object.new
    end

  end ## Operations

end end
