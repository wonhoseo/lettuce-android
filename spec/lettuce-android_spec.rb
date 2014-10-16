require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "LettuceAndroid" do
  before do
    use_device :my_device
  end
  it "fails" do
    my_device.debug "logger debug test"
    #puts " test ##"
    #Lettuce::Android::Operations.default_device.debug "my test message1"
    #Lettuce::Android::Operations.default_device.debug "my test message2"
    #fail "hey buddy, you should probably rename this file and start specing for real"
  end
end
