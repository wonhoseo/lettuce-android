

require 'pathname'    

require 'lettuce-android/window'

module Lettuce module Android module Operations

  class ViewNotFoundError < RuntimeError
    def initialize attr, value, root
      if value.instance_of? Regexp
        msg = "Couldn't find View with %s that matches '%s' in tree with root=%s" % [attr, value.source, root]
      else
        msg = "Couldn't find View with %s='%s' in tree with root=%s" % [attr, value, root]
      end
      super msg
    end    
  end
  
  class View
    
    DEBUG = true
    DEBUG_WINDOWS = true
    DEBUG_COORDS = true
    DEBUG_STATUSBAR = false
    
    VIEW_CLIENT_TOUCH_WORKAROUND_ENABLED = false
    
    USE_ADB_CLIENT_TO_GET_BUILD_PROPERTIES = true
    SKIP_CERTAIN_CLASSES_IN_GET_XY_ENABLED = false
    # visibility
    VISIBLE = 0x0
    INVISIBLE = 0x4
    GONE = 0x8
    
    attr_accessor :parent
    attr_reader :build
    attr_reader :attributes
    attr_reader :device
    
    class << self
      def factory (arg1, arg2, version = -1, force_view_server_use = false)
        if arg1.is_a?(::Hash)
          cls = nil
          attrs = arg1
        else
          cls = ar1
          attrs = nil
        end
        if arg2.instance_of?(View)
          view = arg2
          device = nil
        else
          device = arg2
          view = nil
        end
        if attrs and attrs.has_key?('class')
          clazz = attrs['class']
          if clazz == 'android.widget.TextView'
            return TextView.new(attrs, device, version, force_view_server_use)
          elsif clazz == 'android.widget.EditText'
            return EditText.new(attrs, device, version, force_view_server_use)
          else
            return View.new(attrs, device, version, force_view_server_use)
          end
        elsif cls
          if view
            return cls.dup(view)
          else
            return cls.new(atts, device, version, force_view_server_use)
          end
        elsif view
          # a shallow copy of y
          return view.dup
        else
          return View.new(attrs, device, version, force_view_server_use)
        end
      end
    end
    
    def initialize(attributes, device, version = -1, force_view_server_use = false)
      init_logger()
      @attributes = attributes
      @device = device
      @force_view_server_use = force_view_server_use
      @childern = []
      @parent = nil
      @windows = {}
      @current_focus = nil
      init_version_and_build(version)
      @use_uiautomator = device.get_sdk_version() >= 16 and not force_view_server_use
      init_property_keys(@version)
    end  
   
    def initialize_copy(orig)
      @attributes = @attributes.dup
      @device = @device.dup
      @version = @version.dup
      @force_view_server_use = @force_view_server_use.dup
    end

    private
    def init_version_and_build(version=-1)
      @version = version
      @build = {}
      if version != -1
        @build[VERSION_SDK_PROPERTY] = version
      else
        begin
          if USE_ADB_CLIENT_TO_GET_BUILD_PROPERTIES
            @build[VERSION_SDK_PROPERTY] = @device.get_property(VERSION_SDK_PROPERTY).to_i
          else
            @build[VERSION_SDK_PROPERTY] = device.shell('getprop ' + prop).to_i
          end
        rescue
          @build[VERSION_SDK_PROPERTY] = -1
        end
        @version = @build[VERSION_SDK_PROPERTY]
      end      
    end
    
    ID_PROPERTY = 'mID'
    ID_PROPERTY_UI_AUTOMATOR = 'uniqueId'
    TEXT_PROPERTY = 'text:mText'
    TEXT_PROPERTY_API_10 = 'mText'
    TEXT_PROPERTY_UI_AUTOMATOR = 'text'
    LEFT_PROPERTY = 'layout:mLeft'
    LEFT_PROPERTY_API_8 = 'mLeft'
    TOP_PROPERTY = 'layout:mTop'
    TOP_PROPERTY_API_8 = 'mTop'
    WIDTH_PROPERTY = 'layout:getWidth()'
    WIDTH_PROPERTY_API_8 = 'getWidth()'
    HEIGHT_PROPERTY = 'layout:getHeight()'
    HEIGHT_PROPERTY_API_8 = 'getHeight()'
    
    private
    def init_property_keys(version)
      @id_property = nil
      @text_property = nil
      @left_property = nil
      @top_property = nil
      @width_property = nil
      @height_property = nil
      if @version >= 16 and @use_uiautomator
        @id_property, @text_property = ID_PROPERTY_UI_AUTOMATOR, TEXT_PROPERTY_UI_AUTOMATOR
        @left_property, @top_property = LEFT_PROPERTY, TOP_PROPERTY
        @width_property, @height_property = WIDTH_PROPERTY, HEIGHT_PROPERTY
      elsif version > 10 and (version <16 or @use_uiautomator)
        @id_property, @text_property = ID_PROPERTY, TEXT_PROPERTY
        @left_property, @top_property = LEFT_PROPERTY, TOP_PROPERTY
        @width_property, @height_property = WIDTH_PROPERTY, HEIGHT_PROPERTY
      elsif version == 10
        @id_property, @text_property = ID_PROPERTY, TEXT_PROPERTY_API_10
        @left_property, @top_property = LEFT_PROPERTY, TOP_PROPERTY
        @width_property, @height_property = WIDTH_PROPERTY, HEIGHT_PROPERTY
      elsif version >= 7 and version < 10
        @id_property, @text_property = ID_PROPERTY, TEXT_PROPERTY_API_10
        @left_property, @top_property = LEFT_PROPERTY_API_8, TOP_PROPERTY_API_8
        @width_property, @height_property = WIDTH_PROPERTY_API_8, HEIGHT_PROPERTY_API_8
      elsif version >= 1 and version < 7
        @id_property, @text_property = ID_PROPERTY, TEXT_PROPERTY_API_10
        @left_property, @top_property = LEFT_PROPERTY, TOP_PROPERTY
        @width_property, @height_property = WIDTH_PROPERTY, HEIGHT_PROPERTY
      else # version == -1 or version < 1  
        @id_property, @text_property = ID_PROPERTY, TEXT_PROPERTY
        @left_property, @top_property = LEFT_PROPERTY, TOP_PROPERTY
        @width_property, @height_property = WIDTH_PROPERTY, HEIGHT_PROPERTY
      end
    end
    
    private
    def get_item(key)
      return @attributes[key]
    end
    
    DEBUG_GETATTR = false
    
    def get_attr(name)
      if DEBUG_GETATTR
        logger.debug "    get_attr(#{name}), version: #{@build[VERSION_SDK_PROPERTY]} "
      end
      if @attributes.has_key?(name)
        r = @attributes[name]
      elsif @attributes.has_key?(name+'()')
        r = @attributes[name+'()']
      elsif name.count('_') > 0
        mangle_list = all_possile_name_with_colon(name)
        mangle_name = mangle_list & @attributes.keys()
        if mangle_name.length > 0 and @attributes.has_key?(mangle_name[0])
          r = @attributes[mangle_name[0]]
        else
          raise ArgumentError, name
        end
      else
        # try remving 'is' prefix
        if DEBUG_GETATTR
          logger.debug "    get_attr: trying without 'is' prefix"
        end
        suffix = name[2..-1].lower()
        if @attributes.has_key?(suffix)
          r = @attributes[suffix]
        else
          raise ArgumentError, name
        end  
      end
      # if the method name starts with 'is' let's assume its return value is boolean
      r = true if r == 'true'
      r = false if r == 'false'
      return r
    end
    
    # return 
    def all_possile_name_with_colon(name)
      list = []
      count =name.count('_') 
      0.upto(count) do |i|
        list << name.sub!("_",":")
      end
      return list
    end
    
    public
    def get_class
      @attributes['class']
    end
    
    def get_id
      @attributes['resource-id'] || @attributes[@id_property]
    end
    
    def get_contents_description
      @attributes['content-desc']
    end
    
    # Gets the parent.
    def get_parent
      @parent
    end

    def get_text
      @attributes[@text_property]
    end
    
    def get_width
      if @use_uiautomator
        bounds = @attributes['bounds']
        return bounds[1][0] - bounds[0][0]
      else
        @attributes[@width_property].to_i   
      end
    end
    
    def get_height
      if @use_uiautomator
        bounds = @attributes['bounds']
        return bounds[1][1] - bounds[0][1]
      else
        @attributes[@height_property].to_i   
      end
    end
    
    def get_unique_id
      @attributes['unique_id']
    end    
    
    GET_VISIBILITY_PROPERTY = 'getVisibility()'
    # Gets the View visibility
    def get_visibility
      begin
        if @attributes[GET_VISIBILITY_PROPERTY] == 'VISIBILE'
          return VISIBILE
        elsif @attributes[GET_VISIBILITY_PROPERTY] == 'INVISIBILE'
          return INVISIBILE
        elsif @attributes[GET_VISIBILITY_PROPERTY] == 'GONE'
          return GONE
        else
          return -2
        end
      rescue
        return -1
      end
    end
    
    # Gets the View X coordinate
    def get_x
      if DEBUG_COORDS
        logger.debug "get_x(), %s %s ## %s" % [get_class(), get_id(), get_unique_id()]
      end
      x = 0
      if @use_uiautomator
        x = @attributes['bounds'][0][0]
      else
        begin
          if @attributes.has_key?(GET_VISIBILITY_PROPERTY) and @attributes[GET_VISIBILITY_PROPERTY] == 'VISIBLIE'
            left = @attributes[@left_property].to_i
            x += left
            if DEBUG_COORDS
              logger.debug "get_x(), VISIBLE adding #{left}"
            end            
          end 
        end
      end
      if DEBUG_COORDS
        logger.debug "get_x() return #{x}"
      end
      return x
    end
    
    # Gets the View Y coordinate
    def get_y
      if DEBUG_COORDS
        logger.debug "get_y(), %s %s ## %s" % [get_class(), get_id(), get_unique_id()]
      end
      y = 0
      if @use_uiautomator
        y = @attributes['bounds'][0][1]
      else
        begin
          if @attributes.has_key?(GET_VISIBILITY_PROPERTY) and @attributes[GET_VISIBILITY_PROPERTY] == 'VISIBLIE'
            top = @attributes[@top_property].to_i
            x += top
            if DEBUG_COORDS
              logger.debug "get_y(), VISIBLE adding #{top}"
            end            
          end 
        end
      end
      if DEBUG_COORDS
        logger.debug "get_y() return #{y}"
      end
      return y
    end
    
    def get_xy(debug=false)
      if DEBUG_COORDS
        logger.debug "get_xy(), %s %s ## %s" % [get_class(), get_id(), get_unique_id()]
      end      
      x = get_x
      y = get_y
      if @use_uiautomator
        return [x,y]
      end
      # Hierarchy accumulated X and Y
      hx, hy = 0, 0
      cur_parent = @parent
      until cur_parent.nil?
        if SKIP_CERTAIN_CLASSES_IN_GET_XY_ENABLED
          if ['com.android.internal.widget.ActionBarView',
             'com.android.internal.widget.ActionBarContextView',
             'com.android.internal.view.menu.ActionMenuView',
             'com.android.internal.policy.impl.PhoneWindow$DecorView' ].include? parent.get_class()
             cur_parent = cur_parent.parent
             next             
          end
        end
        hx += cur_parent.get_x
        hy += cur_parent.get_y
        cur_parent = cur_parent.parent
      end
      wxy, wvy = dump_windows_information(debug)
      fw = @windows[@current_focus]
      sbw, sbh = obtain_statusbar_dimensions_if_visible
      statusbar_offset = 0
      pwx, pwy = 0, 0
      if fw
        if DEBUG_COORDS 
          logger.debug "    get_xy: focus window=#{fw}, sb=#{[sbw, sbh]}"
        end
        if fw.wvy <= sbh # it's very unlikely that fw.wvy < sbh, that is a window over the statusbar
          statusbar_offset = sbh
          logger.debug "    get_xy: considering offset=#{sbh}" if DEBUG_STATUSBAR
        else
          logger.debug "    get_xy: ignoring offset=#{sbh}"if DEBUG_STATUSBAR
        end
        if fw.py == fw.wvy
          logger.debug "     get_xy: fw.py, fw.wvy=#{[fw.py, fw.vwy]} : same" if DEBUG_STATUBAR
          pwx = fw.px
          pwy = fw.py
        else
          logger.debug "     get_xy: fw.py, fw.wvy=#{[fw.py, fw.vwy]} : no adjustment" if DEBUG_STATUBAR
        end
      end
      if DEBUG_COORDS or DEBUG_STATUSBAR or debug
        logger.debug "    get_xy: return [%d=, %d]" % [x + hx + wvx + pwx, y + hy + wvy - statusbar_offset + pwy ]
        logger.debug "                    x=%d + %d + %d + %d " % [x , hx , wvx , pwx]
        logger.debug "                    y=%d + %d + %d - %d + %d]" % [y , hy , wvy , statusbar_offset , pwy ]
      end
      return [x + hx + wvx + pwx, y + hy + wvy + pwy - statusbar_offset]
    end
    
    def get_coords
      if DEBUG_COORDS
        logger.debug "get_coords(), %s %s ## %s" % [get_class(), get_id(), get_unique_id()]
      end            
      x, y = get_xy()
      w = get_width()
      h = get_height()
      return [x,y, x+w, y+h]
    end
    
    def get_position_and_size
      x, y = get_xy()
      w = get_width()
      h = get_height()
      return [x,y,w, h]
    end
    
    def get_center
      x, y, w, h = get_position_and_size()
      return [x+w/2,y+h/2]
    end
    
    def add(child_view)
      child_view.parent = self
      @childern << child_view
    end
    
    def is_clickable
      return get_attr('isClickable')
    end
    
    def variable_name_from_id
      _id = get_id()
      if _id
        var = _id.gsub('.','_').gsub(':','__').gsub('/','_')
      else
        _id = get_unique_id()
        if %r|id/(?<res_id>[^/]*)(/(?<res_num>\d+))?| =~ _id
          var = $~[:res_id]
          if $~[:res_num]
            var += $~[:res_num]            
          end
          if /^\d/ =~ var
            var = 'id_' + var
          end
        end 
      end       
      return var
    end
    
    # @param filename Absolute path and optional filename receiving the image.
    def write_image_to_file(filename,format='png')
      unless Pathname.new(filename).absolute?
        raise ArgumentError, "write_image_to_file expects an absolute path"
      end
      if Pathname.directory?(fliename)
        filename = Pathname.expand_path(variable_name_from_id()+'.'+format.lower(),filename)
      end
      if DEBUG
        logger.debug "write_image_to_file filename=#{filename}"
      end
      # input Canavs
      #x,y, w, h = get_position_and_size()
      #image = device.take_snapshot
      #canavs = image.canvas.crop(x,y,w,h)
      #save image
      raise "not yet implement"
    end
        
    def to_s
      str = "View["
      str += @attributes.to_s       
      str += "]" + "   parent="
      if parent and parent.attributes.has_key?('class')
        str += parent.attributes['class']
      else
        str += "nil"
      end
      return str      
    end
    
    def to_small_s
      str = "View["
      if @attributes.has_key?("class")
        str += " class" + attribues["class"]        
      end
      str += " id=%s" % get_id()
      str += " ]"
      str += "   parent="
      if parent and parent.attributes.has_key?('class')
        str += parent.attributes['class']
      else
        str += "nil"
      end
      return str
    end
    
    def to_mirco_s
      str = ""
      if @attributes.has_key?("class")
        str += attribues["class"].sub(/.*\./, '')        
      end
      str += " %s" % get_id().sub('id/no_id/', '-')
      str += "@%04d%04d%04d%04d" % get_coords()
      str += ""
      return str
    end
    
    def to_tiny_s
      str = "View[]"
      if @attributes.has_key?("class")
        str += " class="+ attribues["class"].sub(/.*\./, '')        
      end
      str += " id=%s" % get_id().sub('id/no_id/', '-')
      str += " ]"
      return str
    end
    
        
    private
    def dump_windows_information(debug=false)
      @windows = {}
      @current_focus = nil
      dww = device.shell('dumpsys window windows')
      if DEBUG_WINDOWS or debug
        logger.debug dww
      end      
      lines = dww.split(/\n/)
      
      # xxx_re
      win_re = /^ *Window #(?<num>\d+) Window{(?<win_id>[0-9a-f]+) (u\d+ )?(?<activity>\S+?)?.*}:/
      current_focus_re = /^  mCurrentFocus=Window{(?<win_id>[0-9a-f]+) .*/
      view_visibility_re = / mViewVisibility=0x(?<visibility>[0-9a-f]+)/
      containing_frame_re = /^   *mContainingFrame=\[(?<cx>\d+),(?<cy>\d+)\]\[(?<cw>\d+),(?<ch>\d+)\] mParentFrame=\[(?<px>\d+),(?<py>\d+)\]\[(?<pw>\d+),(?<ph>\d+)\]/
      content_frame_re = /^   *mContentFrame=\[(?<x>\d+),(?<y>\d+)\]\[(?<w>\d+),(?<h>\d+)\] mVisibleFrame=\[(?<vx>\d+),(?<vy>\d+)\]\[(?<vx1>\d+),(?<vy1>\d+)\]/
      frames_re = /^   *Frames: containing=\[(?<cx>\d+),(?<cy>\d+)\]\[(?<cw>\d+),(?<ch>\d+)\] parent=\[(?<px>\d+),(?<py>\d+)\]\[(?<pw>\d+),(?<ph>\d+)\]/ 
      content_re = /^     *content=\[(?<x>\d+),(?<y>\d+)\]\[(?<w>\d+),(?<h>\d+)\] visible=\[(?<vx>\d+),(?<vy>\d+)\]\[(?<vx1>\d+),(?<vy1>\d+)\]/
      policy_visibility_re = /mPolicyVisibility=(?<policy_visibility>\S+?) /
                      
      found_win_re_index = 0
      lines.each_with_index do |line,line_index|
        if line_index < found_win_re_index
          next
        end
        if win_re.match(line)
          num, win_id, activity = $~[:num].to_i, $~[:win_id], $~[:activity]
          wvx, wvy, wvw, wvh = 0, 0, 0, 0
          px, py = 0, 0
          visibility, policy_visibility = -1, 0x0
          lines[line_index+1..-1].each_with_index do |line2,line2_index|
            if win_re.match(line2)
              found_win_re_index = line_index+1 + line2_index # start + index
              break
            end
            if view_visibility_re.match(line2)
              visibility = $~[:visibility].to_i
              if DEBUG_COORDS
                logger.debug "__dumpWindowsInformation: visibility=#{visibility}" 
              end
            end
            if @build[VERSION_SDK_PROPERTY] >= 17
              wvx, wvy, wvw, wvh = 0,0,0,0
            elsif @build[VERSION_SDK_PROPERTY] >= 16
              if frames_re.match(line2)
                px, py = $~[:px].to_i, $~[:py].to_i
                if content_re.match(lines[line_index+1+line2_index+1])
                  wvx, vwy = $~[:vx].to_i,$~[:vy].to_i
                  wvw, wvh = ($~[:vx1].to_i - wvx) , ($~[:vy1].to_i - vwy)
                end
              end
            elsif @build[VERSION_SDK_PROPERTY] == 15
              if cotaining_frame_re.match(line2)
                px, py = $~[:px].to_i, $~[:py].to_i
                if content_frame_re.match(lines[line_index+1+line2_index+1])
                  wvx, vwy = $~[:vx].to_i,$~[:vy].to_i
                  wvw, wvh = ($~[:vx1].to_i - wvx) , ($~[:vy1].to_i - vwy)
                end
              end
            elsif @build[VERSION_SDK_PROPERTY] == 10
              if cotaining_frame_re.match(line2)
                px, py = $~[:px].to_i, $~[:py].to_i
                if content_frame_re.match(lines[line_index+1+line2_index+1])
                  wvx, vwy = $~[:vx].to_i,$~[:vy].to_i
                  wvw, wvh = ($~[:vx1].to_i - wvx) , ($~[:vy1].to_i - vwy)
                end
              end
            else
              logger.warn "Unsupported Android version #{@build[VERSION_SDK_PROPERTY]}"
            end
            if policy_visibility_re.match(line2)
              policy_visibility = ($~[:policy_visibility] == 'true') ? 0x0 : 0x08
            end
          end # line2
          @windows[win_id] = Window.new(num, win_id, activity, wvx, wvy, wvw, wvh, px, py, visibility + policy_visibility)
        else
          if current_focus_re =~ line
            @current_focus = Regexp.last_match(:win_id) # $~ eq.to Regexp.last_match
          end
        end
      end
      
      if @windows.has_key?(@current_focus) and @windows[@current_focus].visibility == VISIBILE
        w = @windows[@current_focus]
        return [w.wvx, w.wvy]
      else
        return [0, 0]  
      end  
    end
    
    def obtain_statusbar_dimensions_if_visible
      sbw , sbh = 0, 0
      @windows.each do |win_id, w|
        if w.activity == 'StatusBar'
          if w.wvy == 0 and w.visibility ==0
            sbw = w.wvw
            sbh = w.wvh
          end
          break
        end
      end
      return [sbw, sbh]
    end
    
    public
    def touch(type=DOWN_AND_UP)
      x,y = get_center
      if DEBUG_TOUTCH
        logger.debug  "should touch @ (#{x}, #{y})"
      end
      if VIEW_CLIENT_TOUCH_WORKAROUND_ENABLED and type = DOWN_AND_UP
        logger.warn "view: touch workaround enabled"
        device.touch(x, y, DOWN)
        sleep(50/1000.0)
        device.touch(x, y, UP)
      else
        device.touch(x, y, type)
      end
    end
    
    
    private
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
  
  # TextView class.
  class TextView < View
    
  end
  
  # EditText class.
  class EditText < TextView
    def type(text)
      touch()
      sleep(0.5)
      text.gsub!('%s', '\\%s')
      text.gsub!(' ', '%s')
      @device.type(text)
      sleep(0.5)
    end
    
    def backspace
      touch()
      sleep(1)
      @device.press('KEYCODE_DEL', DOWN_AND_UP)
    end
  end

end end end