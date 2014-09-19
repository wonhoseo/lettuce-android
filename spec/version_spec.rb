require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "LettuceAndroid" do
  it "check version" do
    expect(Lettuce::Android::Version::STRING).to match(/\d+.\d+.\d+/)
  end
end
