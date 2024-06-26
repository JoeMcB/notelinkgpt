# lib/search_helper.rb

require 'evernote_oauth'

module SearchHelper
  def self.search_notes(oauth_token, sandbox, query, notebook_guid = nil, tag_guids = nil, page = 1, page_size = 100)
    client = EvernoteOAuth::Client.new(token: oauth_token, sandbox: sandbox)
    note_store = client.note_store

    filter = Evernote::EDAM::NoteStore::NoteFilter.new
    filter.words = query || ''
    filter.notebookGuid = notebook_guid if notebook_guid
    filter.tagGuids = tag_guids if tag_guids

    offset = (page - 1) * page_size
    notes = note_store.findNotes(filter, offset, page_size).notes

    notes.map do |note|
      { title: note.title, guid: note.guid }
    end
  end
end
