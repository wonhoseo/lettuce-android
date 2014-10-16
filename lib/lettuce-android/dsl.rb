# encoding: utf-8

module Lettuce module Android
  module DSL
    def use_device(name, serialno = nil)
      define_singleton_method name.to_sym do |*args, &block|
        Lettuce::Android::Operations.using_device(serialno, &block)
      end
    end
  end
end end
