require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require_relative 'spec_helper'

describe "ViewClient" do
  #include Lettuce::Android::Operations
  before do
    use_device :my_device
    #@my_vc = Lettuce::Android::ViewClient.new(my_device, my_device.serialno)
  end 
    
  it ".new" do
    device = my_device #wait_for_connection()
    vc = Lettuce::Android::ViewClient.new(my_device, my_device.serialno)
    expect(vc).not_to be_nil
  end

  it "#dump" do
    device = my_device 
    vc = Lettuce::Android::ViewClient.new(my_device, my_device.serialno)
    vc.dump
  end
end
