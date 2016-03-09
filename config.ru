$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'slack-gamebot'

if ENV['RACK_ENV'] == 'development'
  puts 'Loading NewRelic in developer mode ...'
  require 'new_relic/rack/developer_mode'
  use NewRelic::Rack::DeveloperMode
end

NewRelic::Agent.manual_start

SlackGamebot::App.instance.prepare!

Thread.abort_on_exception = true

Thread.new do
  EM.run do
    EM.next_tick do
      SlackGamebot::Service.start_from_database!
    end
  end
end

run Api::Middleware.instance
