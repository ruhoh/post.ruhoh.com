$: << File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth-github'
require 'erb'
require 'json'
require 'fileutils'

require 'database'
require 'repo'
require 'mapping'
require 'user'


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

def ensure_user
  return true if session[:user]
  @body = erb :splash
  halt(erb :master)
end

def current_user
  session[:user]
end

get '/' do
  ensure_user

  @mapping = Mapping.new(current_user.nickname)
  if params[:domain]
    @mapping.domain = params[:domain].to_s.downcase
    if @mapping.save
      Repo.new({
        "repository" => {
          "name" => "#{current_user.nickname}.ruhoh.com", 
          "owner" => {
            "name" => current_user.nickname
          }
        }
      }).try_deploy
    end
  end

  @current_user = current_user
  full_name = "#{current_user.nickname}/#{current_user.nickname}.ruhoh.com"
  @repos = [{
    "html_url" => "http://github.com/#{full_name}",
    "full_name" => full_name
  }]

  @body = erb :home
  erb :master
end

post '/' do
  payload = JSON.parse(params['payload'])
  repo = Repo.new(payload)
  repo.try_deploy
end

# Support both GET and POST for callbacks
%w(get post).each do |method|
  send(method, "/auth/:provider/callback") do
    session[:user] = User.new(env['omniauth.auth']) # => OmniAuth::AuthHash
    redirect '/'
  end
end

get '/auth/failure' do
  puts params[:message]
  redirect '/'
end

get '/logout' do
  session.clear
  redirect '/'
end
