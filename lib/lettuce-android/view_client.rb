#!/usr/bin/env ruby -wKU
# encoding: utf-8

require 'logger'
require 'nokogiri'

require 'lettuce-android/env'
require 'lettuce-android/view'
require 'lettuce-android/ui_automator_parser'

module Lettuce module Android module Operations
  
  class ViewClient
    
    DEBUG = false
    DEBUG_DEVICE = false
    DEBUG_RECEIVED = false
    DEBUG_TREE = false
    
    ADB_DEFAULT_PORT = 5555
    
    # View server port
    VIEW_SERVER_PORT = 4939
    # version sdk property
    VERSION_SDK_PROPRETY = 'ro.build.version.sdk'
    VERSION_RELEASE_PROPERTY = 'ro.build.version.release'
    # class method
    
    VIEW_SERVER_HOST = '127.0.0.1'
    
    USE_ADB_CLIENT_TO_GET_BUILD_PROPERTIES = true
    
    
    TRAVERSE_CIT = 'traverse_show_class_id_and_text'
    TRAVERSE_CITUI = 'traverse_show_class_id_text_and_unique_id'
    TRAVERSE_CITCD = 'traverse_show_class_id_text_and_content_description'
    TRAVERSE_CITC = 'traverse_show_class_id_text_and_center'
    TRAVERSE_CITPS = 'traverse_show_class_id_text_position_and_size'
        
    class << self
      
      def obtain_adb_path
        Env.adb_path
      end
      
      def map_serialno(serialno)
        serialno.strip!
        if %r|^(\d{1,3}\.){3}\d{1,3}$|.match(serialno)
          return serialno + ':%d' % ADB_DEFAULT_PORT
        end
        
        if %r|^(\d{1,3}\.){3}\d{1,3}:\d+$|.match(serialno)
          return serialno
        end
        
        if %r|[.*()+]|.match(serialno)
          raise ArgumentError, "Regular expression not supported as serialno in ViewClient"
        end
        return serialno
      end
      
      #@param extra_info [Proc] the view method to add extra info
      #@param no_extra_ino [bool] Don't add extra_info 
      def traverse_show_class_id_and_text(view, extra_info=nil, no_extra_info = nil)     
        begin
          eis = ''
          if extra_info
            #eis = extra_info.call(view).to_s
            #if view.response_to?
            eis = view.__send__(extra_info).to_s
            if not eis and not no_extra_info.nil?
              eis = no_extra_info
            end
          end
          if eis
            eis = ' ' + eis
          end
          return '%s %s %s%s' % [view.get_class(), view.get_id(), view.get_text(), eis]
        rescue Error => ex
          return "Error in view=%s:  %s" % [view.to_small_str(), ex]
        end
      end
      def traverse_show_class_id_text_and_unique_id(view)
        return traverse_show_class_id_and_text(view, "get_unique_id")
      end
      
      def traverse_show_class_id_text_and_content_description(view)
        return traverse_show_class_id_and_text(view, "get_content_description", "NAF")
      end
      
      def traverse_show_class_id_text_and_center(view)
        return traverse_show_class_id_and_text(view, "get_center", "NAF")
      end
      
      def traverse_show_class_id_text_position_and_size(view)       
        return traverse_show_class_id_and_text(view, "get_position_and_size")
      end
      
      def __traverse__(view, indent="", transform="to_s", stream=$stdout)
        unless view
          return
        end
        if respond_to?(transform)
          s = __send__(transform, view)
        end
        if s
          ius = "%s%s" % [indent, s] # unicode ?
          stream.puts ius
        end
        for child in view.childern 
          ViewClient.__traverse__(child, indent+"  ", transform, stream)
        end
      end
    end
    
    attr_reader :device
    attr_reader :serialno
    
    def initialize(device, serialno, options = {})
      init_logger()
      init_device(device)
      init_serialno(serialno)

      options = init_options(options)
      init_adb(options[:adb])
      @root = nil
      @views_by_id = {}
      init_display()
      init_build()
      init_ro()
      @force_view_server_use = options[:forceviewserveruse]
      @use_uiautomator = device.get_sdk_version() >= 16 and not options[:forceviewserveruse]
      if DEBUG
        logger.debug " init: use_ui_automator=#{@use_uiautomator}, sdk=#{@build[VERSION_SDK_PROPERTY]}, force_view_server_use=#{@force_view_server_use}"
      end
      # If UIAutomator is supported by the device it will be used
      @ignore_uiautomator_killed = options[:ignoreuiautomatorkilled]
      init_text_property()
      start_view_server(options[:startviewserver], options[:localport], options[:remoteport])
      
      #The list of windows as obtained by L{ViewClient.list()}
      @windows = nil
      
      if options[:autodump]
        dump()
      end  
    end
  
    def dump(window=-1,sleep_delay=1)
      if sleep_delay > 0
        sleep(sleep_delay)
      end
      
      if @use_uiautomator
        dump_with_uiautomator()
      else
        dump_with_view_server(window)
      end
      
    end
  
    # 
    # private methods
    # 
    private
    def init_device device
      unless device
        raise "Device is not connected"
      else
        @device = device
      end      
    end
    
    def init_serialno serialno
      if serialno.nil?
        raise ArguementError "serialno cannot be nil"
      else
        @serialno = ViewClient.map_serialno(serialno)
      end      
      if DEBUG_DEVICE
        logger.debug "ViewClient: using device with serialno:%s" % @serialno
      end
    end

    def init_options(options={})
      options[:adb] = options[:adb] || nil      
      options[:autodump] = options.has_key?(:autodump) ? options[:autodump] : true
      options[:forceviewserveruse] = options.has_key?(:forceviewserveruse) ? options[:forceviewserveruse] : false
      options[:localport] ||= VIEW_SERVER_PORT
      options[:remoteport] ||= VIEW_SERVER_PORT
      options[:startviewserver] = options.has_key?(:startviewserver) ? options[:startviewserver] : true
      options[:ignoreuiautomatorkilled] ||= false
      options
    end
    
    def init_adb(adb)
      if adb
        if not Pathname.executable?(adb)
          raise RuntimeError, "adb=#{adb} is not exectuable"
        end
      else
        adb = obtain_adb_path
      end
      @adb = adb
    end

    def obtain_adb_path
        Env.adb_path
    end
        
    def init_display
      # The map containing the device's display properties: width, height and density
      @display = {}
      for property in ['width', 'height', 'density']
        @display[property] = -1
        if USE_ADB_CLIENT_TO_GET_BUILD_PROPERTIES
          begin
            @display[property] = Integer device.get_property('display.'+property)
          rescue
            logger.warn "Couldn't determine display %s" % property
          end
        else
          #nothins    
        end
      end
    end

    def init_build
      @build = {}
      # The map containing the device's build properties: version.sdk, version.release
      for prop in [VERSION_SDK_PROPERTY, VERSION_RELEASE_PROPERTY]
        @build[prop] = -1
        begin
          if USE_ADB_CLIENT_TO_GET_BUILD_PROPERTIES
          @build[prop] = device.get_property(prop)
          else
          @build[prop] = device.shell('getprop ' + prop)               
          end
        rescue
          logger.warn "Couldn't determine build %s" % prop
        end
        if prop == VERSION_SDK_PROPERTY
          begin
            @build[prop] = Integer @build[prop]
          rescue ArgumentError
            @build[prop] = -1
          end
        end
      end
      return @build
    end
    
    def init_ro
      @ro = {}
      #The map containing the device's ro properties: secure, debuggable
      for property in ['secure', 'debuggable']        
        begin
          @display[property] = device.get_property('ro.'+property)
        rescue
          logger.warn "Couldn't determine ro %s" % property
          @display[property] = 'UNKNOWN'
        end
      end      
    end
    
    TEXT_PROPERTY_UI_AUTOMATOR = 'text'
    TEXT_PROPERTY_API_10 = 'mText'
    TEXT_PROPERTY = 'text:mText'
    
    def init_text_property
      if @use_uiautomator
        @text_property = TEXT_PROPERTY_UI_AUTOMATOR
      else
        if @build[VERSION_SDK_PROPRETY] <= 10
          @text_property = TEXT_PROPERTY_API_10
        else
          @text_property = TEXT_PROPERTY
        end
      end
    end
    
    def start_view_server(enable_view_server, local_port, remote_port)
      unless @use_uiautomator
        if enable_view_server
          response1 = device.shell('service call window 3')
          unless service_response(response1)
            begin
              response2 = device.shell('service call window 1 i32 %d' % remote_port)
              assert_service_response(response2)
            rescue
              msg = 'Cannot start view server.' \
                'This only works on emulator and devices running developer versions.' \
                'Does hierarchyviewer work on your device?' \
                'See https://github.com/dtmilano/AndroidViewClient/wiki/Secure-mode\n' \
                'Device properties:' \
                "    ro.secure=#{@ro['secure']}" \
                "    ro.debuggable=#{@ro['debuggable']}"
              raise RuntimeError, msg
            end
          end
        end
        
        @local_port = local_port
        @remote_port = remote_port
        forward_cmd = "#{adb_command} -s #{@serialno} forward tcp:#{@local_port} tcp:#{@remote_port}"
        logger.debug forward_cmd
        logger.debug `#{forward_cmd}`
      end
    end
    
    def adb_command
      "#{obtain_adb_path} -s #{serialno}"
    end    
    
    def assert_service_response(response)
      unless service_reponse(reponse)
        raise RuntimeError, 'Invalid response received from service.'
      end
    end

    PARCEL_TRUE = "Result: Parcel(00000000 00000001   '........')\r\n"
    def service_response(response)
      if DEBUG
        logger.debug "serviceResponse: comparing '%s' vs Parcel(%s)" % [response, PARCEL_TRUE]
      end  
      result = (response == PARCEL_TRUE)
      return result
    end
    
    def dump_with_uiautomator
      # Using /dev/tty this works even on devices with no sdcard
      received = device.shell('uiautomator dump /dev/tty >/dev/null')
      received_xml = assert_valid_ui_automator_dump(received)
      set_views_form_uiautomator(received_xml)
    end
    
    


    private
    def assert_valid_ui_automator_dump(received)
      unless received
        raise RuntimeError, 'ERROR: Empty UiAutomator dump was received' 
      end
      if DEBUG
        @received = received
      end
      if DEBUG_RECEIVED
        logger.debug "received #{received.length} chars"
        logger.debug "\n#{received}\n"
      end
      if /[\n\S]*Killed[\n\r\S]*/m =~ received
        raise RuntimeError, "ERROR: UiAutomator output contains no valid information. UiAutomator was killed, no reason given."
      end
      if @ignore_uiautomator_killed
        if DEBUG_RECEIVED
          logger.debug "ignoring UiAutomator Killed"
        end
        killed_re = %r|</hierarchy>[\n\S]*Killed|m 
        if killed_re =~ received
          received.sub!(killed_re,'</hierarchy>')
        elsif DEBUG_RECEIVED
          logger.debug "UiAutomator Killed: NOT FOUND!"
        end
        dump_to_dev_tty_re = %r|</hierarchy>[\n\S]*UI hierchary dumped to: /dev/tty.*|m
        if dump_to_dev_tty_re =~ received
          received.sub!(dump_to_dev_tty_re, '</hierarchy>')
        end
        # API19 seems to send this warning as part of the XML.
        # Let's remove it if present
        received.sub!('WARNING: linker: libdvm.so has text relocations. This is wasting memory and is a security risk. Please fix.\r\n', '')
        if DEBUG_RECEIVED
          logger.debug "received=#{received}"
        end
      end
      if received.match(%r|\[: not found|)
        raise RuntimeError, "ERROR: Some emulator images (i.e. android 4.1.2 API 16 generic_x86) does not include the '[' command." \
          "While UiAutomator back-end might be supported 'uiautomator' command fails." \
          "You should force ViewServer back-end."
      end
      return received
    end

    def set_views_form_uiautomator(received)
      if received.nil? or received.empty?
        raise ArgumentError, "received is empty"
      end
      @views = []
      parser_tree_from_uiautomator_dump(received)
      if DEBUG
        logger.debug "there are #{@views.length} views in this dump"
      end
    end
    
    def parser_tree_from_uiautomator_dump received
      doc = UiAutomatorParser.new(@device, @build[VERSION_SDK_PROPERTY])
      parser = Nokogiri::XML::SAX::Parser.new(doc)
      parser.parse(received)
      @root = doc.root
      @views = doc.views
      @views_by_id = Hash[@views.collect{|view| [view.get_unique_id(), view]}]
    end
    
    def dump_with_view_server(window=-1)
      if window.kind_of?(String)
        if window != '-1'
          list(0)
          
          found = false
          @windows.each do |win_id, package|
            if package == window
              window = win_id
              found = true
              break
            end
            if win_id == window.to_i
              window = win_id
              found = true
              break
            end
            if win_id == window.to_h
              window = win_id
              found_true
              break
            end
          end
          
          unless found
            raise RuntimeError, "ERROR: Cannot find window '%s' in %s" % [window, @windows]
          end
          
        else
          window = -1
        end
      end
      
      view_server_command = 'dump %x\r\n' % window
      received = receive_from_view_server(view_server_command)
      
      if received
        received = received.encode('utf-8', :undef => :replace)  
      end
      
      set_views(received)
      
      if DEBUG_TREE
        traverse(@root)
      end
      @views
    end
    
    # return the list of windows
    def list(sleep_delay = 1)
      if sleep_delay > 0
        sleep(sleep_delay)
      end
      if @use_uiautomator
        raise "ot implemented yet: listing windows with UiAutomator"
      end
      received = receive_from_view_server('list\r\n')
      
      lines = received.split(/\n/)
      lines.each do |line|
        unless line
          break
        end
        if /DONE/ =~ line
          break
        end
        values = line.split(' ')
        if values.length > 1
          package = values[1]
        else
          package = 'UNKNOWN'
        end
        if values.length > 0
          wid = values[0]
        else
          wid = '00000000'
        end
        @windows[wid.to_h] = package
      end
      @windows            
    end
    
    private
    def receive_from_view_server(command)
      socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
      sockaddr = Socket.pack_sockaddr_in(@local_port, VIEW_SERVER_HOST)
      begin
        socket.connect(sockaddr)
      rescue Exception => ex
        raise ex
      end
      socket.send(command)
      received = ""
      done_re = /DONE/
      while true
        received += socket.read(1024)
        if done_re.match(received[-7..-1])
          break
        end 
      end
      socket.close()
      
      if DEBUG
        @received = received
      end
      if DEBUG_RECEIVED
        logger.debug "received #{received.length} chars"
        logger.debug "\n#{received}\n"
      end
            
      return received
    end
    
    public
    # receivce string from view_server
    def set_views(received)
      if received.nil? or received.empty?
        raise ArgumentError, "received is empty or nil"
      end
      @views = []
      parser_tree(received.split('\n'))      
    end
    
    def parser_tee(received_lines)
      @root = nil
      @views_by_id = {}
      @views = []
      parenet = nil
      parents = []
      tree_level = -1
      new_level = -1
      last_view = nil
      received_lines.each do |v|
        if v.empty? or v=='DONE' or v == 'DONE.'
          break
        end
        attrs = split_attrs(v)
        unless @root
          if v[0]== ' '
            raise "Unexpected root element starting with ' '."
          end
          @root = View.factory(attrs, @device, @build[VERSION_SDK_PROPERTY], @force_view_server_use)
          tree_level = 0
          new_level = 0
          last_view = @root
          parent = @root
          parents << parent
        else
          new_level = v.length - v.lstrip().length()
          if new_level == 0
            raise RuntimeError, "newLevel==0 treeLevel=%d but tree can have only one root, v=%s" % [tree_level, v]
          end
          if new_level == tree_level
            parent.add(child)
            last_view = child
          elsif new_level > tree_level
            if (newLevel - treeLevel) != 1
              raise RuntimeError, "newLevel jumps %d levels, v=%s" % [(newLevel-treeLevel), v]
            end
            parent = lastView
            parents << parent
            parent.add(child)
            last_view = child
            tree_level = new_level
          else # new_level < tree_level
            (tree_level-new_level).times do 
              parents.pop()
            end
            parent = parents.pop()
            parents << parent
            parent.add(child)
            tree_level = new_level
            last_view = child
          end
        end
        @views << last_view
        @views_by_id[last_view.get_unique_id()]=last_view
      end
      return @views
    end
    
    def split_attrs(args)
      if @use_uiautomator
        raise RuntimeError, "This method is not compatible with UIAutomator"
      end
      text_re = %r|#{@text_property}=(?<len>\d+),|
      if text_re.match(args)
        data = Regexp.last_match
        text_len = data[:m].to_i
        offset_start,offset_end = data.offset[:len]
        s1 = args[offset_end.upto(offset_end+text_len)]
        ws = u"\xfe"
        s2 = s1.gsub(' ', ws)
        args.sub!(s1,s2)        
      end      
      # RE
      id_re = %r|(?<view_id>id/\S+)|
      attr_re = %r|(?<attr>\S+?)(?<parens>\(\))?=(?<len>\d+),(?<val>[^ ]*)| 
      hash_re = %r|(?<class>\S+?)@(?<oid>[0-9a-f]+)|
      attrs = {}
      view_id = nil
      if id_re.match(args)
        view_id = $~[:view_id]
        logger.debug "found view with id = #{view_id}" if DEBUG
      end
      
      args.split().each do |attr|
        if attr_re.match(attr)
          _attr = $~[:attr]
          _parens = $~[:parens] ? '()' : ''
          _len = $~[:len].to_i
          _val = $~[:val] 
          if _len != _val.length
            logger.warn "Invalid len: expected: %d   found: %d   s=%s   e=%s" % [_len, _val.length, _val[0..50], _val[-50..-1]]
          end
          if _attr == @text_property
            #restore spaces tha have ben replaced
            _val = _val.gsub(WS, ' ')
          end
          attrs[_attr + _parens] = _val
        else
          if hash_re.match(attr)
            attrs['class'] = $~[:class]
            attrs['oid'] = $~[:oid]
          else
            logger.debug "doesn't match" if DEBUG
          end
        end        
      end
      
      if true # was assing_view_by_id
        unless view_id
          # If the view has NO_ID we are assigning a default id here (id/no_id) which is
          # immediately incremented if another view with no id was found before to generate
          # a unique id
          view_id = "id/no_id/1"
        end
        if @views_by_if.include? view_id
          # sometimes the view ids are not unique, so let's generate a unique id here
          i = 1
          loop do 
            if @view_by_id.exclude?(new_id)
              new_id = view_id.sub(/\d+$/,'') + "/%d" % i
              break
            end
            i = i+1
          end
          view_id = new_id
        end
        attrs['unique_id'] = view_id
      end
      return attrs
    end
    
    public
    def traverse(root="ROOT", indent="", transform="to_s", stream = $sysout)
      if root.kind_of?(String) and root == "ROOT"
        root = @root
      end
      
      return ViewClient.__traverse__(root, indent, transform, stream)
    end
    
    def find_view_by_id(view_id, view="ROOT", view_filter=nil)
      unless root
        return nil
      end
      if view.kind_of?(String) and view == "ROOT"
        return find_view_by_id(view_id, @root, view_filter)
      end
      
      if root.get_id == view_id
        if view_filter
          if __send__(view_filter, view)
            return view
          end
        else
          return view
        end        
      end
      
      if view_id.match(%r|^id/no_id|) or view_id.match(%r|^id/.+/.+|)
        if view.get_unique_id() == view_id
          if view_filter
            if __send__(view_filter, view)
              return view              
            end
          else
            return view
          end
        end
      end
      
      found_view = view.children.find { |child| find_view_by_id(view_id, child, view_filter) }
      if found_view
        if view_filter
          if __send__(view_filter, found_view)
            return found_view
          end
        else
          return found_view
        end
      else
          nil
      end
    end
    
    def find_view_by_id_or_raise(view_id, view="ROOT", view_filter=nil)
      found_view = find_view_by_id(view_id, view, view_filter)
      if found_view
        return found_view
      else
        raise ViewNotFoundError("ID", view_id, view)
      end
    end
    
    def find_view_by_tag(tag, view="ROOT")
      return find_view_with_attribute('getTag()', tag, view)
    end
    
    def find_view_by_tag_or_raise(tag, view = "ROOT")
      found_view = find_view_by_tag(tag, view)
      if found_view
        return found_view
      else
        raise ViewNotFoundError("tag", tag, view)
      end
    end
    
    def find_view_with_attribute(attr, val, view="ROOT")
      return find_view_with_attribute_in_tree(attr, val, view)
    end
    
    private
    def find_view_with_attribute_in_tree(attr, val, view)
      unless @root
        logger.error "ERROR: no root, did you forget to call dump()?"
        return nil
      end
      
      if view.kind_of?(String) and view == "ROOT"
        view = @root
      end
      
      if DEBUG
        logger.debug "find_view_with_attribute_in_tree: checking if view=%s hass attr=%s eq_to %s" % [view.to_small_s, attr, val]
      end      
      
      if val.kind_of?(Regexp)
        return find_view_with_attribute_in_tree_that_matches(attr, val, view)
      else
        if view and view.attributes.has_key?(attr) and view.attributes[attr] == val
          logger.debug "find_view_with_attribute_in_tree %s" % view.to_small_s() if DEBUG
          return view
        else
          v = view.children.find {|child| find_view_with_attribute_in_tree(attr, val, child)}
          if v
            return v
          end
        end
      end
      return nil
    end
    
    def find_view_with_attribute_in_tree_or_raise(attr, val, view)
      found_view = find_view_with_attribute_in_tree(attr, val, view)
      if found_view
        return found_view
      else
        raise ViewNotFoundError(attr, val, view)
      end
    end
    
    def find_view_with_attribute_in_tree_that_matches(attr, regex, view="ROOT")
      return __find_view_with_attribute_in_tree_that_matches(attr,regex, view)
    end
    
    def __find_view_with_attribute_in_tree_that_matches(attr, regex, view)
      unless @root
        logger.error "ERROR: no root, did you forget to call dump()?"
        return nil
      end
      
      if view.kind_of?(String) and view == "ROOT"
        view = @root
      end
      
      if DEBUG
        logger.debug "find_view_with_attribute_in_tree_that_matches: checking if view=%s attr=%s matches %s" % [view.to_small_s, attr, regex]
      end
      
      if view and view.attributes.has_key?(attr) and regex.match(view.attributes[attr])
        logger.debug "find_view_with_attribute_in_tree %s" % view.to_small_s() if DEBUG
        return view
      else
        v = view.children.find {|child| find_view_with_attribute_in_tree_that_matches(attr, val, child)}
        if v
          return v
        end
      end
      return nil      
    end
    
    def find_view_with_text(text, view="ROOT")
      if DEBUG
        logger.debug "find_view_with_text (#{text}, #{view})"
      end
      
      if text.kind_of?(Regexp)
        return find_view_with_attribute_that_matches(@text_property, text, view)
      else
        return find_view_with_attribute(@text_property, text, view)
      end
    end
    
    def find_view_with_text_or_raise(text, view="ROOT")
      found_view = find_view_with_text(text, view)
      if found_view
        return found_view
      else
        raise ViewNotFoundError(@text_property, text, view)
      end
    end
    
    # Finds the View with the specified content description
    def find_view_with_content_description(val, view="ROOT")
      return find_view_with_attribute_in_tree('content-desc', text, view)
    end
    
    # Finds the View with the specified content description
    def find_view_with_content_description_or_raise(val, view="ROOT")
      found_view = find_view_with_content_description(val, view)
      if found_view
        return found_view
      else
        raise ViewNotFoundError('content-desc', val, view)
      end      
    end
    
    public
    def find_views_cotaining_point(x,y, filter = nil)
      unless filter
        filter = Proc.new {|v| true}
      end
      return @views.find{|v| v.cotaining_point(x,y) and filter.call(v)}
    end
    
    def get_views_by_id
      @views_by_id
    end
    
    def focused_window_position
      get_focused_window_id
    end
    
    def get_sdk_version
      @build[SDK_VERSION_PROPERTY]
    end

    def is_keyboard_shown
      dim = device.shell('dumpsys input_method')
      if dim
        return dim.include?("mInputShown=true")
      end
      return false
    end
    
    def write_image_to_file(filename, format='png')
      unless Pathname.new(filename).absolute?
        raise ArgumentError, "write_image_to_file expects an absolute path"
      end
      if Pathname.directory?(fliename)
        filename = Pathname.expand_path(variable_name_from_id()+'.'+format.lower(),filename)
      end
      if DEBUG
        logger.debug "write_image_to_file filename=#{filename}"
      end
      #device.take_snapshot(filename, format)      
    end
    
    def logger
      @logger_
    end

    private
    def init_logger
      log = Logger.new(STDOUT)
      log.progname = "Device"
      #log.datetime_format = "%Y-%m-%d %H:%M:%S.%L"
      log.datetime_format = "%m-%d %H:%M:%S.%6N"
      #log.formatter = proc do |severity, datetime, progname, msg|
      #  "#{Time.now.strftime("%Y-%m-%d %H:%M:%S")},#{severity}, #{progname} - #{msg}\n"
      #end        
      # FATAL ERROR WARN INFO DEBUG
      #log.level = Logger::WARN
      log.level = Logger::DEBUG
      @logger_ = log 
    end
    
  end
  
end end end
