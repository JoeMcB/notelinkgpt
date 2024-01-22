require 'sinatra'
require 'sinatra/namespace'

require 'lib/encryption_helper'

class Api < Sinatra::Base
  register Sinatra::Namespace
  helpers EncryptionHelper

  # Set view to parent directory + /views
  set :views, File.expand_path('../../views', __FILE__)

  def sandbox?
    ENV['SANDBOX'] == 'true'
  end

  namespace '/api' do
    before do
      halt 401, { error: 'Access Denied' }.to_json unless params[:user_id]

      begin
        encrypted_user_id = params[:user_id]
        user_id = decrypt(encrypted_user_id, ENV['ENCRYPTION_KEY'])
        @oauth_token = $redis.get("user:#{user_id}:access_token")

        halt 401, { error: 'User not logged in' }.to_json unless @oauth_token
      rescue OpenSSL::Cipher::CipherError
        halt 401, { error: 'Bad Hash' }.to_json unless @oauth_token
      end
    end

    get '/notes' do
      page_size = params[:page_size]&.to_i || 10
      page_number = params[:page_number]&.to_i || 1
      offset = (page_number - 1) * page_size

      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: sandbox?)

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

      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: sandbox?)

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
      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: sandbox?)

      note_store = client.note_store

      # Fetch note by guid
      note = note_store.getNote(params[:guid], true, false, false, false)

      # Render note metadata and content to JSON
      response = { title: note.title, guid: note.guid, content: note.content }

      response.to_json
    end
  end
end
