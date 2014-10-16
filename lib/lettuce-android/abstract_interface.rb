

module Lettuce module Android 

  module AbstractInterface
  
    class InterfaceNotImplementedError < NoMethodError
    end
  
    def self.included(klass)
      klass.__send__(:include, AbstractInterface::Methods)
      klass.__send__(:extend, AbstractInterface::Methods)
    end
  
    module Methods
  
      def api_not_implemented(klass)
        caller.first.match(/in \`(.+)\'/)
        method_name = $1
        raise AbstractInterface::InterfaceNotImplementedError.new("#{klass.class.name} needs to implement '#{method_name}' for interface #{self.name}!")
      end
  
    end
  
  end

end end
