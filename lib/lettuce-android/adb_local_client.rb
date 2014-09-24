
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
        if is_transport_set?
          @build[VERSION_SDK_PROPRETY] = get_property(VERSION_SDK_PROPRETY)
        end
      end
      
      def serialno=(serialno)
        super(serialno)
        if is_transport_set?
          @build[VERSION_SDK_PROPRETY] = get_property(VERSION_SDK_PROPRETY)
        end
      end

      def get_system_property(name, strip = true)
        
      end
      
      def get_property(name, strip = true)        
      end
      
      def get_sdk_version
        #return @build[Lettuce::Android::Operations::AdbConnection::VERSION_SDK_PROPRETY]
        return @build[VERSION_SDK_PROPRETY]
      end

    end
  end
end end