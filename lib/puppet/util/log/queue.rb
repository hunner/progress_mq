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
    resource_count = Hash.new(0)
    #@resources_processed = Hash.new(0)
    #@resources_failed = Hash.new(0)
    resource_keep = Array.new
    @last_resource = Hash.new("")
    @config = Hash.new([])
    @message = Hash.new
    begin
      @catalog = Puppet::Face[:catalog,'0.0.1'].find(Puppet[:certname])
    rescue => e
      p e
    end
    begin
      @config[:hosts] = @catalog.resource_keys.map do |type, title|
        #p "#{type} #{title}"
        resource_count[type.downcase] += 1
        resource = @catalog.resource("#{type}[#{title}]").to_ral
        case type
        when 'Progress_server'
          {
            :login    => resource[:user],
            :passcode => resource[:password],
            :host     => resource[:host],
            :port     => resource[:port],
            :ssl      => resource[:ssl],
          }
        when 'Progress_resource'
          resource[:resources].each do |r_type|
            resource_keep << r_type.downcase
          end
          nil
        when 'Progress_target'
          @config[:targets] += resource[:targets]
          nil
        end
      end.compact
      resource_keep.each do |type|
        @message[type] = Hash.new
        @message[type]['progress'] = Hash.new
        @message[type]['progress']['total'] = resource_count[type]
        @message[type]['progress']['processed'] = 0
        @message[type]['progress']['failed'] = 0
      end
    rescue => e
      p e
      throw Puppet::ParseError
    end
    @config[:hosts]
    #connection.publish(@hosts[0][:target], "loaded")
  end

  def connections
    return @connections if @connections
    @connections = Stomp::Connection.new({:hosts => @config[:hosts]})
    Puppet.notice(@message.to_json) if @connections
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

  private

  def convert_msg(msg)
    message = Hash.new
    begin
      if count = JSON.parse(msg.message)
        message = count
      end
    rescue JSON::ParserError => e
      case msg.source
      when 'Puppet'
        case msg.message
        when /Finished catalog run/
          @message.each do |k,v|
            v['progress']['processed'] = v['progress']['total'] - v['progress']['failed']
          end
          message = @message
        end
      when /.+\/.+/
        begin
          if m = msg.source.match(/(([^\/]+?)\[([^\[]+?)\])\/[a-z]+$/)
            resource_type = m[2].downcase
            return if @message[resource_type].nil? or @message[resource_type].empty?
            if @last_resource[:name] != m[1]
              if msg.level == :err
                @message[resource_type]['progress']['failed'] += 1
              else
                @message[resource_type]['progress']['processed'] += 1
              end
              @last_resource[:name] = m[1]
              @last_resource[:type] = resource_type
            else
              if msg.level == :err
                @message[resource_type]['progress']['failed'] += 1
                @message[resource_type]['progress']['processed'] -= 1
              else
                return
              end
            end
            message[resource_type] = @message[resource_type].clone
            message[resource_type]['title'] = m[3]
          end
        rescue => e
          p e
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
