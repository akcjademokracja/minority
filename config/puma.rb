#!/usr/bin/env puma

# Read environment
@env = ENV['RACK_ENV'] || 'development'
require 'dotenv'
Dotenv.load ".env.#{@env}"

@dir = ENV['PUMADIR'] || ENV['PWD']
@port = ENV['PORT']

workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 10)
threads threads_count / 2, threads_count

preload_app!

environment ENV['RACK_ENV'] || 'development'

if @port
  port        @port
else
  bind "unix:///tmp/identity.puma.sock"
end

pidfile "/tmp/identity.puma.pid"
state_path "/tmp/identity.puma.state"

on_worker_boot do
  ActiveSupport.on_load(:active_record) do
    ActiveRecord::Base.establish_connection
    ActiveRecord::Base.connection.schema_search_path = Settings.databases.schema
    RedshiftDB.establish_connection
  end
end

before_fork do
  if threads_count > ActiveRecord::Base.connection.pool.size or
    threads_count > RedshiftDB.connection.pool.size
    raise ArgumentError, "Puma threads count (#{threads_count}) exceeds connecton pool for primary (ActiveRecord::Base) or RedshiftDB database, add pool=#{threads_count} option to DATABASE_URL and REDSHIFT_URL environment variable" 
  end

  ActiveRecord::Base.connection_pool.disconnect!
  RedshiftDB.connection_pool.disconnect!
end
