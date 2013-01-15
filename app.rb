$: << File.join(File.dirname(__FILE__), 'lib')

require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth-github'
require 'erb'
require 'json'
require 'fileutils'

require 'rack-flash'
require 'parse-ruby-client'
require 'octokit'

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
  
secret = File.join('config', 'secret.json')
secret = File.open(secret) {|f| JSON.parse(f.read) }
use Rack::Session::Cookie, secret: secret["key"]
use OmniAuth::Builder do
  github_config = File.join('config', 'github2.json')
  next unless File.exist?(github_config)
  
  github_config = File.open(github_config) {|f| JSON.parse(f.read) }
  provider :github, github_config["client_id"], github_config["secret"]
end

parse = File.join('config', 'parse.json')
parse = File.open(parse) {|f| JSON.parse(f.read) }
Parse.init application_id: parse["application_id"],
           api_key: parse["api_key"]

use Rack::Flash

def ensure_user
  return true if session[:user]
  @body = erb :splash
  halt(erb :master)
end

def current_user
  session[:user]
end

# Homepage - list repos and websites
get '/' do
  ensure_user
  
  @current_user = current_user
  @repos = Octokit.repositories(@current_user.nickname)
  @repo_dictionary = Repo.dictionary({"user" => current_user.nickname })
  
  @body = erb :home
  erb :master
end

# Service provider sends POST webhook payload here.
post '/' do
  payload = JSON.parse(params['payload'])
  repo = Repo.find_or_build_with_payload(payload)

  repo.try_deploy ? 204 : 400
end

# Update domain mapping on repo.
post '/repos/:name' do
  ensure_user
  halt "No domain sent" unless params[:domain]

  record = Repo.all({"domain" => params[:domain]})[0]

  if record # Domain already exists.
    if record['user'] == current_user.nickname
      if record['name'] == params[:name]
        flash[:notice] = "Saved but not changed."
        redirect '/' # no change.
      else
        flash[:error] = "Your repo '#{record['name']}' already has this domain." +
          " Edit this first then try again."
      end
    else
       flash[:error] = "Another user has configured '#{params[:domain]}'." +
        " If you own '#{params[:domain]}' please email me to resolve:"+
        " <a href='mailto:plusjade@gmail.com'>plusjade@gmail.com</a>."
    end
  else
    repo = Repo.find_or_build({
      "user" => current_user.nickname,
      "name" => params[:name]
    })
    repo.custom_domain = params[:domain]
  
    if repo.save
      if repo.try_deploy
        flash[:error] = "Saved but: #{repo.error}"
      else
        flash[:success] = "Domain updated and compiled."
      end
    else
      flash[:error] = repo.error
    end
  end
  
  redirect "/"
end

# Trigger compile update on repo.
post '/repos/:name/compile' do
  ensure_user
  repo = Repo.find_or_build({
    "user" => current_user.nickname,
    "name" => params[:name]
  })
  
  if repo.try_deploy
    flash[:success] = "Successfully compiled!"
  else
    flash[:error] = repo.error
  end

  redirect '/'
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
