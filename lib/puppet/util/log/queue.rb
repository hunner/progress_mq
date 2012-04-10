require 'time'
require 'rubygems'
require 'json'
require 'puppet/face'

Puppet::Util::Log.newdesttype :queue do
  def self.suitable?(obj)
    Puppet.features.stomp?
  end

  def initialize
    #configfile = File.join([File.dirname(Puppet.settings[:config]), "queue.yamaoeul"])
    #Puppet.warning("#{self.class}: config file #{configfile} not readable") unless File.exist?(configfile)
    @resource_count = Hash.new(0)
    @resources_counted = Hash.new(0)
    @seen_resources = Array.new
    begin
      @catalog = Puppet::Face[:catalog,'0.0.1'].find(Puppet[:certname])
    rescue => e
      p e
    end
    @config[:hosts] = @catalog.resource_keys.map do |type, title|
      @resource_count[type.downcase] += 1
      case type
      when 'Progress'
        resource = @catalog.resource("#{type}[#{title}]")
        {
          :login    => resource[:user],
          :passcode => resource[:password],
          :host     => resource[:host],
          :port     => resource[:port],
          :ssl      => resource[:ssl],
          :target   => resource[:target]
        }
      when 'Progress_resource'
        resource[:resources].each do |r_type|
          @resources_counted[r_type.downcase] = 0
        end
        nil
      when 'Progress_target'
        @config[:targets] += resource[:resources]
        nil
      end
    end.compact
    @hosts
    #connection.publish(@hosts[0][:target], "loaded")
  end

  def connections
    return @connections if @connections
    @connections = Stomp::Connection.new({:hosts => @config[:hosts]})
    Puppet.notice({"resource_count" => @resource_count}.to_json) if @connections
    @connections
  end

  def config_version
    @config_version ||= @catalog.version
  end

  def handle(msg)
    if event = convert_msg(msg)
      @config[:targets].each do |target|
        Timeout::timeout(2) do
          connections.publish(target, event.to_json)
        end
      end
    end
  end

  def convert_msg(msg)
    message = Hash.new
    begin
      if count = JSON.parse(msg.message) and count['resource_count']
        message = count
      end
    rescue JSON::ParserError => e
      case msg.source
      when 'Puppet'
      when /.+\/.+/
        if m = msg.source.split(/\//)[-2].match(/(.+)\[(.+)\]/)
          #require 'ruby-debug' ; debugger ; 1
          @seen_resources << m[0]
          resource_type = m[1].downcase
          message[resource_type] = m[2]
          message['progress'] = "#{@resources_counted[resource_type] += 1}/#{@resource_count[resource_type]}"
        end
      end
    end
    {
      "host"            => Facter.value("fqdn"),
      "catalog_version" => config_version,
      "time"            => msg.time,
      "content"         => message
    } unless message.empty?
  end
end
