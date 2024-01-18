require_relative './index'

if ENV['RACK_ENV'] == 'development'
  require 'rack/unreloader'
  Unreloader = Rack::Unreloader.new{Everlink}
  Unreloader.require Dir.pwd + './index.rb'

  run Unreloader
else
  run Everlink
end
