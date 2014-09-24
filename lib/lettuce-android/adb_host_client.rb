
require 'lettuce-android/adb_connection'

module Lettuce module Android module Operations

    class AdbHostClient < Lettuce::Android::Operations::AdbConnection
      #    endAdbConnection     
      
      #include Lettuce::Android::Operations::AdbConnection
      def initialize options={}
        super options
      end
      
      def check_version      
      end
    end
end end end