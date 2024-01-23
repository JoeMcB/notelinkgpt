require 'sinatra'
require 'sinatra/namespace'

class Api < Sinatra::Base
  register Sinatra::Namespace
  helpers EncryptionHelper
  helpers SearchHelper

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
      results = SearchHelper.search_notes(@oauth_token, sandbox?, query)
      results.to_json
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

    get '/notebooks' do
      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: sandbox?)
      note_store = client.note_store
      notebooks = note_store.listNotebooks
      notebooks.map { |notebook| { name: notebook.name, guid: notebook.guid } }.to_json
    end

    get '/notebooks/:notebook_guid' do
      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: sandbox?)
      note_store = client.note_store
      notebook = note_store.getNotebook(params[:notebook_guid])
      { name: notebook.name, guid: notebook.guid }.to_json
    end

    get '/tags' do
      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: sandbox?)
      note_store = client.note_store
      tags = note_store.listTags
      tags.map { |tag| { name: tag.name, guid: tag.guid } }.to_json
    end

    get '/tags/:tag_guid' do
      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: sandbox?)
      note_store = client.note_store
      tag = note_store.getTag(params[:tag_guid])
      { name: tag.name, guid: tag.guid }.to_json
    end

    get '/notebooks/:notebook_guid/notes/search' do
      query = params[:q]
      results = SearchHelper.search_notes(@oauth_token, sandbox?, query, params[:notebook_guid])
      results.to_json
    end

    get '/tags/:tag_guid/notes' do
      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: sandbox?)
      note_store = client.note_store
      filter = Evernote::EDAM::NoteStore::NoteFilter.new
      filter.tagGuids = [params[:tag_guid]]
      notes = note_store.findNotes(filter, 0, 100).notes
      notes.map { |note| { title: note.title, guid: note.guid } }.to_json
    end

    get '/notes/:guid/versions' do
      client = EvernoteOAuth::Client.new(token: @oauth_token, sandbox: sandbox?)
      note_store = client.note_store
      versions = note_store.listNoteVersions(params[:guid])
      versions.map { |version| { title: version.title, updateSequenceNum: version.updateSequenceNum } }.to_json
    end

    get '/search' do
      query = params[:q]
      notebook_guid = params[:notebook_guid]
      tag_guids = params[:tag_guids]
      page = params[:page].to_i || 1
      page_size = params[:page_size].to_i || 100

      results = SearchHelper.search_notes(@oauth_token, sandbox?, query, notebook_guid, tag_guids, page, page_size)
      results.to_json
    end
  end
end
