# encoding: utf-8

require 'lettuce-android/adb_host_client'
require 'lettuce-android/adb_keymap'
require 'benchmark'

module Lettuce module Android

  class AdbLocalClient < Lettuce::Android::AdbHostClient
    include Lettuce::Android::AdbKeymap
    UP = 0
    DOWN = 1
    DOWN_AND_UP = 2
    VERSION_SDK_PROPRETY = 'ro.build.version.sdk'
    
    attr_reader :lettuce_server_port
    
    def initialize(serialno, options = {})
      super(serialno, options)

      @build = {}
      initialize_attrs_after_setup_serialno
    end

    def serialno=(serialno)
      super(serialno)
      initialize_attrs_after_setup_serialno
    end
    
    def initialize_attrs_after_setup_serialno
      initialize_test_agent_port
      initialize_version_sdk_property
    end
    
    def initialize_test_agent_port
      if @is_transport_set
        @lettuce_server_port = Lettuce::Android::Operations.config.obtain_new_port(serialno)
        debug "Device init test_agent_port=#{lettuce_server_port}"
      end      
    end
    
    def initialize_version_sdk_property
      if @is_transport_set
        @build[VERSION_SDK_PROPRETY] = get_property_internal(VERSION_SDK_PROPRETY)
      end      
    end

    def shell(cmd)
      recv =""
      if cmd
        close()
        response = benchmark do
          init_socket()
          transport_command = 'host:transport:%s' % @serialno
          send_message(transport_command)
          #shell_command = #command("shell:#{cmd}")
          shell_command = "shell:#{cmd}"
          send_message(shell_command)
          recv = receive(nil,false)
          {action:shell_command , response: recv}
        end
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

    def press(name, type=DOWN_AND_UP)
      cmd = 'input keyevent %s' % name
      shell(cmd)
    end

    def long_press(name, duration = 0.5, dev='/dev/input/event0')
      if name[0..3] == 'KEY_'
        name = name[4..-1].upcase
      end
      if KEY_MAP.include?(name)
        shell('sendevent %s 1 %d 1' % [dev, KEY_MAP[name]])
        shell('sendevent %s 0 0 0' % [dev])
        sleep(duration)
        shell('sendevent %s 1 %d 0' % [dev, KEY_MAP[name]])
        shell('sendevent %s 0 0 0' % [dev])
        return
      end
      version = get_sdk_version
      if version >= 19
        cmd = 'input keyevent --longpress %s' % name
        shell(cmd)
      else
        raise RuntimeError, "long_press: not support for API < 19 (version=#{version})"
      end
    end

    def start_activity(component=nil, flags=nil, uri=nil)
      cmd = 'am start'
      cmd += ' -n %s' % component unless component.nil?
      cmd += ' -f %s' % flags unless flags.nil?
      cmd += ' %s' % uri unless nil
      out = shell(cmd)
      if %r[(Error type)|(Error: )|(Cannot find 'App')]im =~ out
        raise RuntimeError, out
      end
    end

    # return image CunkyImage
    def take_spanshot(reconnect=false)
      raise "not yet implement"

      close()
      init_socket()
      transport_command = 'host:transport:%s' % @serialno
      dispatch(transport_command)
      dispatch('framebuffer:')
      # case 1:// version
      #    return 12; // bpp, size, width, height, 4*(lengh, offset)
      received_header = receive(1*4 + 12*4)
      # L: unsigned long(32-bit) < : little-endian *: will use up all remaining elements
      version, bpp, size, width, height, roffset, rlen, boffset, blen, goffset, glen, aoffset, alen \
          = received_header.to_s.unpack('L<'*13)
      # take_snapshot: [1, 32, 8294400, 1080, 1920, 0, 8, 16, 8, 8, 8, 24, 8]
      logger.debug "#{TAG} take_snapshot: #{[version, bpp, size, width, height, roffset, rlen, boffset, blen, goffset, glen, aoffset, alen]}"
      offsets = { roffset => 'R', goffset => 'G', boffset => 'B'}
      if bpp == 32
        if alen != 0
          offsets[aoffset] = 'A'
        else
          #warnings.warn 'framebuffer is specified as 32bpp but alpha length is 0'
          logger.warn 'framebuffer is specified as 32bpp but alpha length is 0'
        end
      end
      arg_mode = ''
      offsets.sort.each do |key,value|
        arg_mode << value
      end
      logger.debug "#{TAG} take_snapshot: #{[version, bpp, size, width, height, roffset, rlen, boffset, blen, goffset, glen, aoffset, alen, arg_mode]}"
      if arg_mode == 'BGRA'
        arg_mode = 'RGBA'
      end
      if bpp == 16
        mode = 'RGB'
        arg_mode += ';16'
      else
        mode = arg_mode
      end
      dispatch('\0', false)
      logger.debug "#{TAG}    takeSnapshot: reading %d bytes" % size
      received_data = receive(size)
      if reconnect
        init_socket()
        set_transport()
      end
      logger.debug "#{TAG}    takeSnapshot: Image.frombuffer(%s, [%d, %d], %s, %s, %s, %s, %s)" % [mode, width, height, 'data', 'raw', arg_mode, 0, 1]

      # StreamImporting
      # #from_abgr_stream, #from_bgr_stream, #from_rgb_stream, #from_rgba_stream
      if arg_mode == 'RGBA'
        image = ChunkyPNG::Image.from_rgba_stream(width, height, received_data)
      elsif arg_mode == 'ABGR'
        image = ChunkyPNG::Image.from_abgr_stream(width, height, received_data)
      elsif arg_mode == 'RGB'
        image = ChunkyPNG::Image.from_rgb_stream(width, height, received_data)
      elsif arg_mode == 'BGR'
        image = ChunkyPNG::Image.from_bgr_stream(width, height, received_data) # 1 sec
      else
        logger.warn "#{TAG}   take_snapshot unsupport mode %s" % arg_mode
      end

      logger.debug "#{TAG} save : my_file.png"
      image.save('my_file.png') # 6 secs
      logger.debug "#{TAG} save : done"
    end

    def touch(x,y,event_type=DOWN_AND_UP)
      cmd = "input tap %d %d" % [x, y]
      shell(cmd)
    end

    def drag((x0,y0), (x1,y1), duration, step=1)
      logger.debug("#{TAG} drag([#{x0}, #{y0}], [#{x1}, #{y1}],#{duration},#{step})")
      version = get_sdk_version
      if version <= 15
        raise RuntimeError, "drag: API <= 15 not supported (version=%d)" % version
      elsif version <= 17
        shell('input swipe %d %d %d %d' % [x0, y0, x1, y1])
      else
        shell('input touchscreen swipe %d %d %d %d %d' % [x0, y0, x1, y1, duration])
      end
    end

    def wake
      unless is_screen_on
        shell('input keyevent POWER')
      end
    end

    def is_screen_on
      logger.debug "#{TAG} is_screen_on()"
      result = false
      screen_on_re = /mScreenOnFully=(true|false)/
      recv = shell('dumpsys window policy')
      recv.each_line do |line|
        logger.debug line
        if m = screen_on_re.match(line)
          logger.debug m
          result = (m[1] == 'true')
          break
        end
      end
      logger.debug "#{TAG}    is_screen_on return #{result}"
      return result
    end

    def is_locked
      logger.debug "#{TAG} is_locked()"
      result = false
      showing_lock_screen_re = /mShowingLockscreen=(true|false)/
      recv = shell('dumpsys window policy')
      recv.each_line do |line|
        logger.debug line
        if m = showing_lock_screen_re.match(line)
          logger.debug m
          result = (m[1] == 'true')
          break
        end
      end
      logger.debug "#{TAG}    is_locked return #{result}"
      return result
    end

    def unlock
      # Unlocks the screen of the device.
      shell('input keyevent MENU')
      shell('input keyevent BACK')
      # TODO wait and check is_locked value
    end
    
    private
    
    def benchmark
      result = nil
      realtime = Benchmark.realtime do
        result = yield
      end
      debug "action '#{result[:action]}' completed in #{(realtime * 1000).to_i}ms"
      result[:response]
    end

  end

end end