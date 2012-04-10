#!/usr/bin/ruby

require 'rubygems'
require 'stomp'

amqport = 61613
amqserver = "training.puppetlabs.lan"

@user = "mcollective"
@password = "3RQTuUM41Gq97EjFNxxa"

credentials = {:hosts => [{:login => @user, :passcode => @password, :host => amqserver, :port => amqport, :ssl => true}]}

@conn = Stomp::Connection.open(credentials)

STDOUT.sync = true

@conn.subscribe("/queue/events")

puts("Listening for log messages on /queue/events@#{amqserver}")

while true
  msg = @conn.receive.body

  puts (JSON.pretty_generate(JSON.parse(msg)))
end
