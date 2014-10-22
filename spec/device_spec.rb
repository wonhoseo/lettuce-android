# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

#require 'lettuce-android/device'

describe "Device" do
  
  describe ".new" do

    it "expect return not nil" do
      device = Lettuce::Android::Device.new(nil)
      expect(device).not_to eq(nil)
    end

  end
  
  describe "#serialno=" do
    it "init and set serialno" do
      device = Lettuce::Android::Device.new(nil)
      device.serialno = '.*'
      expect(device).not_to eq(nil)
      
    end    
  end
  
  describe "#get_sdk_version" do
    it "return int" do
      device = Lettuce::Android::Device.new(nil)
      device.serialno = '.*'
      device.get_sdk_version
    end
  end
  
  describe "#launch_settings" do
    it "#launch_settings setup" do
      device = Lettuce::Android::Operations.default_device
      device.launch_settings
      device.scroll_to_text "잠금화면"
      device.click_text "잠금화면"
    end
  end
end

