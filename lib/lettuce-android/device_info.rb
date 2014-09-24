

module Lettuce module Android  module Operations
  
  class DeviceInfo
    attr_reader :serialno, :status, :qualifiers
    
    def initialize(serialno, status, qualifiers=nil)
      @serialno, @status = serialno, status
      @qualifiers = qualifiers || {}
    end
          
    def to_s        
      "#<#{@serialno}, #{@status}, #{@qualifiers}>"
    end
    
    def to_a
      [@serialno, @status, @qualifiers]
    end 
  end

end end end