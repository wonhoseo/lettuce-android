# encoding: utf-8

require_relative 'spec_helper'

describe "Operations" do  
  include Lettuce::Android::Operations
  it "wait_for_connection" do    
    device, serialno = wait_for_connection()
    expect(device).not_to be_nil
    expect(serialno).not_to be_nil
  end
end
