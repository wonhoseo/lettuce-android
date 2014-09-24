# encoding: utf-8

require_relative 'spec_helper'

describe "ViewClient" do
  include Lettuce::Android::Operations
  
  it ".new" do
    device,serialno = wait_for_connection()
    vc = Lettuce::Android::Operations::ViewClient.new(device,serialno)
    expect(vc).not_to be_nil
  end
end
