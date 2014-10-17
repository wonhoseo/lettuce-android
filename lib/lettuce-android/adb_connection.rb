
require 'socket'
require 'lettuce-android/abstract_interface'
require 'lettuce-android/adb_log_formatter'

module Lettuce module Android

  class AdbConnection

    include Lettuce::Android::AbstractInterface
    include Lettuce::Android::AdbLogFormatter

    DEFAULT_ADB_HOSTNAME = '127.0.0.1' # replaced 'localhost'
    DEFAULT_ADB_PORT = 5037

    VERSION_SDK_PROPERTY = 'ro.build.version.sdk'

    attr_reader :serialno
    attr_reader :socket

    def initialize(serialno, options = {})
      @serialno = serialno
      @hostname = options[:hostname] || DEFAULT_ADB_HOSTNAME
      @port = options[:port] || DEFAULT_ADB_PORT
      settransport=  options.has_key?(:settransport) ? options[:settransport] : true
      @reconnect = options.has_key?(:reconnect) ? options[:reconnect] : true
      init_socket()
      check_version()
      @is_transport_set = false
      if settransport and (not @serialno.nil?)
        set_transport()
      end
    end

    def serialno=(serialno)
      if @is_transport_set
        raise ArgumentError, "Transport is already set, serialno cannot be set once this is done."
      end
      @serialno=serialno
      set_transport()
    end

    def reconnect=(reconncet)
      @reconnect=reconnect
    end

    def check_version
      AdbConnection.api_not_implemented(self)
    end

    def set_transport
      AdbConnection.api_not_implemented(self)
    end

    def check_connected
      unless @socket
        raise RuntimeError, "ERROR: Not connected"
      else
        if @socket.closed?
          return false
        end
      end
      return true
    end

    def close
      if @socket and not @socket.closed?
        @socket.close()
      end
    end

    protected
    def init_socket
      begin
        socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
        sockaddr = Socket.pack_sockaddr_in(@port,@hostname)
        socket.connect(sockaddr)
      rescue Exception => ex
        raise ex
      end
      @socket = socket
    end

    def send_message(message, checkok=true, reconnect=false)
      if not message.match(/^host:/)
        if not @is_transport_set
          set_transport()
        end
      else
        check_connected()
      end
      command = '%04X%s' % [message.length, message]
      socket.write(command)
      if checkok
        check_ok()
      end
      if reconnect
        init_socket()
        set_transport()
      end
    end

    def receive(payloadlength=nil, use_payloadlength=true)
      check_connected()
      if use_payloadlength
        if payloadlength == nil then
          nob = @socket.read(4).hex
        else
          nob = payloadlength
        end
        recv =""
        nr = 0 # number of read
        while nr < nob
          chunk = @socket.read([nob-nr, 4096].min)
          recv << chunk
          nr += chunk.length
        end
        return recv.to_s
      else
        recv =""
        nr = 0 # number of read
        while true
          chunk = socket.read(4096)
          unless chunk
            break
          end
          recv << chunk
          nr += chunk.length
        end
        return recv.to_s
      end
    end

    def check_ok
      check_connected
      result = @socket.read(4)
      if result != 'OKAY'
        error = @socket.read(1024)
        raise RuntimeError, "ERROR: %s %s" % [ result.to_s, error]
      end
      return true
    end

  end # AdbConnection

end end
