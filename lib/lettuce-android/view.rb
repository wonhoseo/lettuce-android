
module Lettuce module Android module Operations

  class View
    
    USE_ADB_CLIENT_TO_GET_BUILD_PROPERTIES = true
    
    attr_accessor :parent
    attr_reader :build
    attr_reader :attributes
    
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
    
    public
    
    def get_unique_id
      @attributes['unique_id']
    end
    
    def add(child_view)
      child_view.parent = self
      @childern << child_view
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