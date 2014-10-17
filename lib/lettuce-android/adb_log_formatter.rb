# encoding:utf-8
require 'logger'

module Lettuce module Android

  module AdbLogFormatter
    Logger::Severity.constants.each do |severity|
      severity_sym = severity.to_s.downcase.to_sym
      define_method severity_sym do |message|
        Lettuce::Android::Operations.config.logger.send(severity_sym, "Device #{serialno}: #{message}")
      end
    end
  end

end end
