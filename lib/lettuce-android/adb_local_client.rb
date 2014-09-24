
require 'lettuce-android/adb_host_client'
module Lettuce module Android
  module Operations
    class AdbLocalClient < Lettuce::Android::Operations::AdbHostClient
      
      #include Lettuce::Android::Operations::AdbHostClient
      VERSION_SDK_PROPRETY = 'ro.build.version.sdk'
      #attr_reader :serialno
      def initialize options={}
        super options
        @build = {}
        if @is_transport_set
          @build[VERSION_SDK_PROPRETY] = get_property(VERSION_SDK_PROPRETY)
        end
      end
      
      def serialno=(serialno)
        super(serialno)
        if @is_transport_set
          @build[VERSION_SDK_PROPRETY] = get_property(VERSION_SDK_PROPRETY)
        end
      end

      def shell(cmd)
        recv =""
        if cmd
          close()
          init_socket()
          transport_command = 'host:transport:%s' % @serialno
          send(transport_command)
          #shell_command = #command("shell:#{cmd}")
          shell_command = "shell:#{cmd}"
          send(shell_command)
          recv = receive(nil,false)
        end
        return recv.to_s    
      end
      def get_system_property(name, strip = true)
      end
      
      def get_property_internal(name, strip = true)
        prop = shell('getprop %s' % name)
        if strip
          prop.chomp!
        end
        return prop        
      end
      def get_property(name, strip = true)
         return get_property_internal(name,strip)       
      end
      
      def get_sdk_version
        #return @build[Lettuce::Android::Operations::AdbConnection::VERSION_SDK_PROPRETY]
        return @build[VERSION_SDK_PROPRETY]
      end

    end
  end
end end