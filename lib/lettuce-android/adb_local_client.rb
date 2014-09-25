
require 'lettuce-android/adb_host_client'
module Lettuce module Android
  module Operations
    class AdbLocalClient < Lettuce::Android::Operations::AdbHostClient
      
      #include Lettuce::Android::Operations::AdbHostClient
      VERSION_SDK_PROPRETY = 'ro.build.version.sdk'
      #attr_reader :serialno
      def initialize options={}
        super options
        @build = {}
        if @is_transport_set
          @build[VERSION_SDK_PROPRETY] = get_property_internal(VERSION_SDK_PROPRETY)
        end
      end
      
      def serialno=(serialno)
        super(serialno)
        if @is_transport_set
          @build[VERSION_SDK_PROPRETY] = get_property_internal(VERSION_SDK_PROPRETY)
        end
      end

      def shell(cmd)
        recv =""
        if cmd
          close()
          init_socket()
          transport_command = 'host:transport:%s' % @serialno
          send(transport_command)
          #shell_command = #command("shell:#{cmd}")
          shell_command = "shell:#{cmd}"
          send(shell_command)
          recv = receive(nil,false)
        end
        return recv.to_s
      end

      
      def get_system_property(name, strip = true)
        get_property(name,strip)
      end
      
      MAP_KEYS = {/display.width/ => "get_display_width",
        /display.height/ => "get_display_height",
        /display.density/ => "get_display_density",
        /.*/ => "get_property_internal" }
        
      private  
      def get_property_internal(name, strip = true)
        prop = shell('getprop %s' % name)
        if strip
          prop.chomp!
        end
        return prop        
      end

      public
      def get_property(name, strip = true)
        MAP_KEYS.each do |k_re, method| 
          if k_re.match(name)
              return __send__(method, name, strip)
          end
        end
        raise ArgumentError, "key='%s' does not match any map entry" % name      
      end

      def get_sdk_version
        return @build[VERSION_SDK_PROPRETY].to_i
      end

      def get_restricted_screen
        #rs_re = /\s*mRestrictedScreen=\((?<x>\d+),(?<y>\d+)\) (?<w>\d+)x(?<h>\d+)/
        window = shell('dumpsys window')
        window.each_line do |line|
          if /\s*mRestrictedScreen=\((?<x>\d+),(?<y>\d+)\) (?<w>\d+)x(?<h>\d+)/ =~ line
            return [x,y,w,h]
          end
        end
        raise RuntimeError, "Couldn't find mRestrictedScreen in dumpsys"
      end

      private
      def get_display_width(name='display.widht', strip=true)
        x,y,w,h = get_restricted_screen
        return w.to_i
      end

      def get_display_height(name='display.widht', strip=true)
        x,y,w,h = get_restricted_screen
        return h.to_i
      end
      
      def get_display_density(name='display.density', strip=true)
        density = get_property_internal('ro.sf.lcd_density')
        return density.to_i
      end

    end
  end
end end