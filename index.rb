require 'sinatra'
require 'evernote_oauth'

CLIENT_KEY = 'goodguylaskygpt-3523'
CLIENT_SECRET = '40658e9884d5fccc65b6941c2683c221b815573bfdad511762d56c8c'
SANDBOX = false # Set false for production

# Override Fixnum to Integer cause Everote client is ancient.
if !defined?(Fixnum)
  Fixnum = Integer
end


get '/' do
  client = EvernoteOAuth::Client.new(
    consumer_key: CLIENT_KEY,
    consumer_secret: CLIENT_SECRET,
    sandbox: SANDBOX
  )

  request_token = client.request_token(:oauth_callback => 'http://localhost:4567/callback')
  session[:request_token] = request_token

  redirect request_token.authorize_url
end

get '/callback' do
  request_token = session[:request_token]
  @access_token = request_token.get_access_token(:oauth_verifier => params[:oauth_verifier])

  # Redirect to the notes listing page
  redirect to('/notes')
end


get '/notes' do
  oauth_token = 'goodguylaskygpt-3523.18D0332E7C1.687474703A2F2F6C6F63616C686F73743A343536372F63616C6C6261636B.43D474EB12CFDD62B0DEFEC8D54F8A07'
  oauth_verifier='67398EAB36620C8F0440B9A340E6A0A5&sandbox_lnb=false'

  client = EvernoteOAuth::Client.new(token: oauth_token, consumer_key:CLIENT_KEY, sandbox:SANDBOX)

  note_store = client.note_store

  # Fetch notes
  filter = Evernote::EDAM::NoteStore::NoteFilter.new
  notes = note_store.findNotes(filter, 0, 10).notes

  # Render notes
  erb :index, locals: { notes: notes }
end
