$: << File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth-github'
require 'erb'
require 'json'
require 'fileutils'

require 'repo'

airbrake_config = File.join('config', 'airbrake.json')
if File.exist?(airbrake_config)
  require 'airbrake'
  airbrake_config = File.open(airbrake_config) {|f| JSON.parse(f.read) }
  Airbrake.configure {|config| config.api_key = airbrake_config['apikey'] }
  use Airbrake::Rack
  enable :raise_errors
end
  
use Rack::Session::Cookie
use OmniAuth::Builder do
  github_config = File.join('config', 'github.json')
  next unless File.exist?(github_config)
  
  github_config = File.open(github_config) {|f| JSON.parse(f.read) }
  provider :github, github_config["client_id"], github_config["secret"]
end

get '/' do
  'POST some GitHub data to me =('
end

post '/' do
  payload = JSON.parse(params['payload'])
  repo = Repo.new(payload)
  repo.try_deploy
end

# Support both GET and POST for callbacks
%w(get post).each do |method|
  send(method, "/auth/:provider/callback") do
    auth = env['omniauth.auth'] # => OmniAuth::AuthHash
    puts auth
  end
end

get '/auth/failure' do
  puts params[:message]
  redirect '/'
end

