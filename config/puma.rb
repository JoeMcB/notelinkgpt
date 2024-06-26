# Puma configuration
workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup      "config.ru"
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

# Ensure Redis connection is closed before forking to a worker.
before_fork do
  $redis.quit if defined?($redis)
end
