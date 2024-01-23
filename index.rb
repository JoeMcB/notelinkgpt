require 'sinatra'
require 'sinatra/namespace'
require 'redis'
require 'dotenv'
require 'rack/ssl-enforcer'

env = ENV['RACK_ENV'] || 'development'
env_files = [
  File.expand_path('../.env', __FILE__),
  File.expand_path("../.env.#{env}", __FILE__)
]
Dotenv.load(*env_files)

$LOAD_PATH.unshift(File.expand_path('../', __FILE__))

require 'evernote_oauth'

require 'lib/fixnum_fix'
require 'lib/encryption_helper'
require 'lib/search_helper'

# Application
require 'app/auth'
require 'app/api'

class NoteLinkGPT < Sinatra::Base
  # Environment variables
  REDIS_URL = ENV['REDIS_URL']

  # Globals
  $redis = Redis.new(url: REDIS_URL)

  # Sinatra Configuration
  use Rack::SslEnforcer if production?

  enable :sessions, :logging

  set :environment, ENV['RACK_ENV']
  set :session_secret, ENV['SESSION_SECRET']
  set :public_folder, File.dirname(__FILE__) + '/public'

  register Sinatra::Namespace

  helpers EncryptionHelper

  # Routes
  get '/' do
    erb :index
  end

  use Auth
  use Api
end
