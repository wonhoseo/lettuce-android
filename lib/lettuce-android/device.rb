
require 'lettuce-android/adb_local_client'

module Lettuce module Android module Operations
    
  class Device < Lettuce::Android::Operations::AdbLocalClient
    #include Lettuce::Android::Operations::AdbLocalClient

    # @return [Device] a new Device instance 
    def initialize options={}
      super options
    end
    
  end
  
end end end
