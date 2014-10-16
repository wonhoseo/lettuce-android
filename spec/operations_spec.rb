# encoding: utf-8

require_relative 'spec_helper'

describe "Operations" do
  before do
    use_device :my_device
  end
  #include Lettuce::Android::Operations
  it "wait_for_connection" do
    #device, serialno = wait_for_connection({ serialno:".*", verbose: true })
    #device, serialno = wait_for_connection({ verbose: true })
    #device = my_device #3 wait_for_connection()
    expect(my_device).not_to be_nil
    my_device.debug "my debug message"
    #expect(serialno).not_to be_nil
  end
end
