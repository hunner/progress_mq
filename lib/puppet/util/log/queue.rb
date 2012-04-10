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
    @resources_completed = Hash.new(0)
    @resources_failed = Hash.new(0)
    @seen_resources = Array.new
    @last_resource = Hash.new
    @config = Hash.new([])
    begin
      @catalog = Puppet::Face[:catalog,'0.0.1'].find(Puppet[:certname])
    rescue => e
      p e
    end
    @config[:hosts] = @catalog.resource_keys.map do |type, title|
      p "#{type} #{title}"
      @resource_count[type.downcase] += 1
      begin
        resource = @catalog.resource("#{type}[#{title}]").to_ral
        case type
        when 'Progress'
          puts "progress"
          puts "progress2"
          {
            :login    => resource[:user],
            :passcode => resource[:password],
            :host     => resource[:host],
            :port     => resource[:port],
            :ssl      => resource[:ssl],
            :target   => resource[:target]
          }
        when 'Progress_resource'
          puts "resource"
          resource[:resources].each do |r_type|
            @resources_completed[r_type.downcase] = 0
          end
          puts "resource2"
          nil
        when 'Progress_target'
          puts "target"
          @config[:targets] += resource[:targets]
          puts "target 2"
          nil
        end
      rescue => e
        p e
        require 'ruby-debug' ; debugger ; 1
        throw Puppet::ArgumentError
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
        case msg.message
        when /Finished catalog run/
        end
      when /.+\/.+/
        if m = msg.source.split(/\//)[-2].match(/(.+)\[(.+)\]/)
          #first resource                 @last_resource.empty?
          #next resource after failed     @last_resource[state] == :err
          #next resource after success    @last_resource[:name] != m[0]
          #next resource after don't-care @last_resource[:name] != m[0]
          #same resource after don't-care @last_resource[:name] != m[0]
          #same resource after care       @last_resource[:name] == m[0]
          if msg.level == :err
            @last_resource = ""
          end
          #require 'ruby-debug' ; debugger ; 1
          @last_resource = m[0]
          @seen_resources << m[0]
          resource_type = m[1].downcase
          message[resource_type] = m[2]
          message['progress'] = {
            'completed' => @resources_completed[resource_type],
            'failed'    => @resources_failed[resource_type],
            'total'     => @resource_count[resource_type]
          }
          @resourecs_completed[resource_type] += 1
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
