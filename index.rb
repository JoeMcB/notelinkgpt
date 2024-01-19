require 'sinatra'
require 'sinatra/namespace'
require 'redis'
require 'dotenv'

env = ENV['RACK_ENV'] || 'development'
env_files = [
  File.expand_path('../.env', __FILE__),
  File.expand_path("../.env.#{env}", __FILE__)
]
Dotenv.load(*env_files)

require 'evernote_oauth'

require_relative './lib/fixnum_fix'

class NoteLinkGPT < Sinatra::Base
  CLIENT_KEY = ENV['CLIENT_KEY']
  CLIENT_SECRET = ENV['CLIENT_SECRET']
  SANDBOX = ENV['SANDBOX'] == 'true'
  REDIS_URL = ENV['REDIS_URL']

  $redis = Redis.new(url: REDIS_URL)

  enable :sessions, :logging
  set :environment, ENV['RACK_ENV']
  set :session_secret, ENV['SESSION_SECRET']

  register Sinatra::Namespace

  get '/' do
    erb :index
  end

  namespace '/auth' do
    get '/' do
      client = EvernoteOAuth::Client.new(
        consumer_key: CLIENT_KEY,
        consumer_secret: CLIENT_SECRET,
        sandbox: SANDBOX
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

      # Redirect to the notes listing page
      redirect to('/api/notes')
    end
  end

  namespace '/api' do
    before do
      halt 401, { error: 'User not logged in' }.to_json unless session[:edam_userId]
      @oauth_token = $redis.get("user:#{session[:edam_userId]}:access_token")
    end

    get '/notes' do
      page_size = params[:page_size]&.to_i || 10
      page_number = params[:page_number]&.to_i || 1
      offset = (page_number - 1) * page_size

      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: SANDBOX)

      note_store = client.note_store

      # Fetch notes
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      notes = note_store.findNotes(filter, offset, page_size).notes

      # Render notes title and guid to JSON
      response = notes.map do |note|
        { title: note.title, guid: note.guid }
      end

      response.to_json
    end

    get '/notes/search' do
      query = params[:q]

      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: SANDBOX)

      note_store = client.note_store

      # Create a NoteFilter with the search query
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.words = query

      # Fetch notes
      notes = note_store.findNotes(filter, 0, 100).notes

      # Render notes title and guid to JSON
      notes.map do |note|
        { title: note.title, guid: note.guid }
      end.to_json
    end

    get '/notes/:guid' do
      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: SANDBOX)

      note_store = client.note_store

      # Fetch note by guid
      note = note_store.getNote(params[:guid], true, false, false, false)

      # Render note metadata and content to JSON
      response = { title: note.title, guid: note.guid, content: note.content }

      response.to_json
    end
  end
end
