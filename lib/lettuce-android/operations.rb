# encoding: UTF-8

module Lettuce module Android

  module Operations

    def log(message)
      $stdout.puts "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} - #{message}" if ARGV.include? "-v" or ARGV.include? "--verbose"
    end
    
    def dump
      default_view_client.dump
    end
    
    
  end ## Operations

end end
