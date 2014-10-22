require 'simplecov'

module SimpleCov::Configuration
  def clean_filters
    @filters = []
  end
end

SimpleCov.configure do
  clean_filters
  add_filter do |src|
    !(src.filename =~ /^#{SimpleCov.root}/) unless src.filename =~ /lettuce-android/
  end
  load_profile 'test_frameworks'
end

ENV["COVERAGE"] && SimpleCov.start do
  add_filter "/.rvm/"
end
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'rspec'
require 'lettuce-android'
require 'lettuce-android/version'
require 'lettuce-android/operations'
require 'lettuce-android/abase'
require 'lettuce-android/dsl'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|

  config.include Lettuce::Android::Operations
  config.include Lettuce::Android::DSL

  config.before(:suite) do
    puts "### before suite ###"
  end
  config.before(:context) do |context|
    puts "*** before context ***"
    #puts context.methods
  end
  config.before(:example) do |ex|
    puts "=== before example ==="
    puts ex.description
    puts ex.example_group
  end
  
  config.after(:suite) do
    puts "### after suite ###"
  end
end
