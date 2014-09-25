
module Lettuce module Android module Operations

  class View
    
    class << self
      def factory
        
      end
    end
    
    def initialize(attributes, device, version = -1, force_view_server_use = false)
      @attributes = attributes
      @childern = []
    end
    
    def add(childview)
      @childern << childview
    end
    
  end

end end end