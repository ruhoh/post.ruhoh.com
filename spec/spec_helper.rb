require 'rubygems'
require 'bundler/setup'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

Dir[File.join(File.dirname(__FILE__), "support/**/*.rb")].each {|f| require f}

require './app'
require 'rspec'
require 'rack/test'
require 'pp'

# Omniauth settings
OmniAuth.config.test_mode = true
OmniAuth.config.add_mock(:github, {
  "email" => "plusjade@gmail.com",
  "name" => "Jade",
  "nickname" => "plusjade",
  "payload" => {
    "provider" => "github",
    "uid" => 123
  },
  "uid" => 123
})
MockSessionHash = {'rack.session' => {"user" => OmniAuth.config.mock_auth[:github]}}

set :environment, :test

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.color_enabled = true
end

