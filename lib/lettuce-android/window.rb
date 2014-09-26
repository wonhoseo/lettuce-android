

  # Window class
  class Window

    attr_reader :num
    attr_reader :win_id
    attr_reader :activity
    attr_reader :wvx, :wvy, :wvw, :wvh
    attr_reader :px, :py
    attr_reader :visibility

    # initialize
    #
    # @param num [Fixnum] Ordering number in Window Manager
    # @param win_id [String] the window ID
    # @param activity [String] the activity (or sometimes other component) owning the window
    # @param wvx [Fixnum] window's virtual X
    # @param wvy [Fixnum] window's virtual Y
    # @param wvw [Fixnum] window's virtual Width
    # @param wvh [Fixnum] window's virtual Height
    # @param px [Fixnum] parent's X
    # @param py [Fixnum] parent's Y
    # @param visibility [Fixnum] visibility of the window
    def initialize(num, win_id, activity, wvx, wvy, wvw, wvh, px, py, visibility)
      @num, @win_id, @activity = num, win_id, activity
      @wvx, @wvy, @wvw, @wvh = wvx, wvy, wvw, wvh
      @px, @py = px, py
      @visibility = visibility
    end
    
    def to_s
      "Window(#{@num}, wid=#{@win_id}, a=#{@activity}, x=#{@wvx}, y=#{@wvy}, w=#{@wvw}, h=#{@wvh}, px=#{@px}, py=#{@py}, v=#{@visibility})"
    end
  end