# encoding: utf-8

require 'lettuce-android/adb_connection'
require 'lettuce-android/device_info'

module Lettuce module Android

  class AdbHostClient < Lettuce::Android::AdbConnection

    ADB_SERVER_VERSION = 31 # <android>/system/core/adb/adb.h and adb.c

    def initialize(serialno, options = {})
      super(serialno,options)
    end

    def check_version(reconnect = true)
      send_message('host:version')
      may_payload = socket.read(4) # return 0x0004 => 4 bytes
      version = socket.read(4) # return 0x00f1 => 31
      if version.hex != ADB_SERVER_VERSION
        raise RuntimeError, "ERROR: Incorrect ADB server version %s (expecting %s)" % [version.hex, ADB_SERVER_VERSION]
      end
      if reconnect
        init_socket()
      end
      return true
    end

    def set_transport
      if not @serialno
        raise ValueError, "serialno not set, empty or None"
      end
      check_connected()
      serialno_re = /#{serialno}/
      found = false
      for device_info in get_devices()
        if serialno_re.match(device_info.serialno)
          found = true
          break
        end
      end
      if not found
        raise RuntimeError, "ERROR: couldn't find device that matches '%s'" % serialno
      end
      @serialno = device_info.serialno
      message = 'host:transport:%s' % @serialno
      send_message(message,false)
      @is_transport_set = true
    end

    def get_devices
      init_socket()
      #send_message('host:devices-l', checkok=false)
      send_message('host:devices-l', false)
      begin
        check_ok()
      rescue RuntimeError => ex
        $stderr.puts "**ERROR", ex
        return nil
      end
      output = receive()
      devices = []
      output.each_line do |line|
        items = line.split(' ')
        serial, status = items[0], items[1]
        qualifiers = {}
        items[2..-1].each do |item|
          key, value = item.split(':')
          qualifiers[key] = value
        end
        devices << DeviceInfo.new(serial, status, qualifiers)
      end
      return devices
    end

  end

end end