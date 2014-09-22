# encoding: utf-8

require_relative 'spec_helper'

describe "Operations" do  
  include Lettuce::Android::Operations
  it "wait_for_connection" do    
    log 'test'
    expect(wait_for_connection()).not_to be_nil
  end
end
