require 'sinatra'
require 'sinatra/namespace'

require 'lib/encryption_helper'

class Auth < Sinatra::Base
  register Sinatra::Namespace
  helpers EncryptionHelper

  # Set view to parent directory + /views
  set :views, File.expand_path('../../views', __FILE__)

  namespace '/auth' do
    get '/' do
      client = EvernoteOAuth::Client.new(
        consumer_key: ENV['CLIENT_KEY'],
        consumer_secret: ENV['CLIENT_SECRET'],
        sandbox: ENV['SANDBOX'] == 'true'
      )

      request_token = client.request_token(:oauth_callback => "#{ENV['PUBLIC_URI']}/auth/callback")
      session[:request_token] = request_token

      redirect request_token.authorize_url
    end

    get '/callback' do
      request_token = session[:request_token]
      access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])

      # Store edam_userId in session
      session[:edam_userId] = access_token.params[:edam_userId]

      # Store the token in Redis
      $redis.set("user:#{session[:edam_userId]}:access_token", access_token.token)

      # Encrypt userId
      encrypted_user_id = encrypt(session[:edam_userId], ENV['ENCRYPTION_KEY'])

      erb :callback, locals: { user_id: encrypted_user_id }
    end
  end
end
