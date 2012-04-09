require 'time'
require 'rubygems'
require 'json'

Puppet::Util::Log.newdesttype :queue do
  def self.suitable?(obj)
    Puppet.features.stomp?
  end

  def initialize
    puts "loading"
    #configfile = File.join([File.dirname(Puppet.settings[:config]), "queue.yamaoeul"])
    #Puppet.warning("#{self.class}: config file #{configfile} not readable") unless File.exist?(configfile)
    #require 'ruby-debug' ; debugger ; 1
    catalog = Puppet::Face[:catalog,'0.0.1'].find(Puppet[:certname])
    @hosts = catalog.resource_keys.map do |type, title|
      next unless type == 'Process'
      resource = catalog.resource("#{type}[#{title}]")
      {
        :login    => resource[:user],
        :passcode => resource[:password],
        :host     => resource[:host],
        :port     => resource[:port],
        :ssl      => resource[:ssl],
        :target   => resource[:target]
      }
    end.compact
    #@config = YAML.load_file(configfile)
    puts "loaded"
    #connection.publish(@config[:portal], "loaded")
  end

  def connections
    @connections ||= Stomp::Connection.new({:hosts => [@hosts]})
  end

  def handle(msg)
    puts "msg"
    @event = convert_msg(msg)
    Timeout::timeout(2) {
      connection.publish(@hosts[0][:target], @event.to_json)
    }
  end

  def convert_msg(msg)
    event = {}
    hostname = Facter["fqdn"].value
    if msg.message =~ /^Applying configuration version \'(\S+)\'$/
      @config_version ||= $1
    end
    event["time"], event["source"], event["host"], event["config_version"], event["content"] = msg.time, msg.source, hostname, @config_version, msg.message
    return event
  end
end
