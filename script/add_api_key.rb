require 'redis'

def set_user_id(token, user_id)
  $redis = Redis.new
  user_id = $redis.hset("api_tokens", token, user_id)
  user_id
end

token = ARGV[0]
user_id = ARGV[1]

begin
  puts "Setting User ID #{user_id} set for token #{token}"
  set_user_id(token, user_id)
  confirm = $redis.hget("api_tokens", token)
  puts "Confirmation: User ID #{confirm} set for token #{token}"
rescue
  puts "Error: #{$!}"
end
