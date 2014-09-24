
require 'socket'
require 'lettuce-android/abstract_interface'



module Lettuce module Android  module Operations
   
  class AdbConnection
    include AbstractInterface
    
    DEFAULT_ADB_HOSTNAME = 'localhost'
    DEFAULT_ADB_PORT = 5037
          
    VERSION_SDK_PROPERTY = 'ro.build.version.sdk'
      
    def initialize(options={})
      serialno = options[:serialno] || nil
      hostname = options[:hostname] || DEFAULT_ADB_HOSTNAME
      port = options[:port] || DEFAULT_ADB_PORT
      settransport=  options.has_key?(:settransport) ? options[:settransport] : true
      reconnect = options.has_key?(:reconnect) ? options[:reconnect] : true
      check_version
       
    end
    
    def serialno=(serialno)
      
    end
    
    def is_transport_set?
      @is_transport_set
    end
    
    def check_version
      AdbConnection.api_not_implemented(self)
    end

    def close
      if @socket and not @socket.closed?
        @socket.close()
      end
    end
    
    private
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
  end
end end end

