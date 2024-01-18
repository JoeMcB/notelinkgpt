require 'sinatra'
require 'sinatra/namespace'
require 'evernote_oauth'

CLIENT_KEY = 'goodguylaskygpt-3523'
CLIENT_SECRET = '40658e9884d5fccc65b6941c2683c221b815573bfdad511762d56c8c'
SANDBOX = false # Set false for production

# Override Fixnum to Integer cause Everote client is ancient.
if !defined?(Fixnum)
  Fixnum = Integer
end

enable :sessions
set :session_secret, '92c4ecd3d5863023d40ef6da1630b50c3d376f81868b419355e599eb6e86e5e9f9c6d56c29e3e59cbc0f80cacfab879bfa2d9e959f4d7970e5cce41ca5aab704'

get '/' do
  erb :index
end

get '/auth' do
  client = EvernoteOAuth::Client.new(
    consumer_key: CLIENT_KEY,
    consumer_secret: CLIENT_SECRET,
    sandbox: SANDBOX
  )

  base_url = "http://localhost:4567"
  request_token = client.request_token(:oauth_callback => "#{base_url}/callback")
  session[:request_token] = request_token

  redirect request_token.authorize_url
end

get '/callback' do
  request_token = session[:request_token]
  access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])

  session[:access_token] = access_token.token
  session[:access_token_secret] = access_token.secret

  # Redirect to the notes listing page
  redirect to('/notes')
end

namespace '/api' do
  get '/notes' do
    page_size = params[:page_size]&.to_i || 10
    page_number = params[:page_number]&.to_i || 1
    offset = (page_number - 1) * page_size

    oauth_token = session[:access_token]
    client = EvernoteOAuth::Client.new(token: oauth_token, sandbox:SANDBOX)

    note_store = client.note_store

    # Fetch notes
    filter = Evernote::EDAM::NoteStore::NoteFilter.new
    notes = note_store.findNotes(filter, offset, page_size).notes

    # Render notes title and guid to JSON
    response = notes.map do |note|
      { title: note.title, guid: note.guid }
    end

    # content_type :json
    response.to_json
  end

  get '/notes/search' do
    query = params[:q]

    oauth_token = session[:access_token]
    client = EvernoteOAuth::Client.new(token: oauth_token, sandbox:SANDBOX)

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
    oauth_token = session[:access_token]
    client = EvernoteOAuth::Client.new(token: oauth_token, sandbox:SANDBOX)

    note_store = client.note_store

    # Fetch note by guid
    note = note_store.getNote(params[:guid], true, false, false, false)

    # Render note metadata and content to JSON
    response = { title: note.title, guid: note.guid, content: note.content }

    # content_type :json
    response.to_json
  end
end
