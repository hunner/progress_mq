require 'time'
require 'rubygems'
require 'json'
require 'puppet/face'

Puppet::Util::Log.newdesttype :queue do
  def self.suitable?(obj)
    Puppet.features.stomp?
  end

  def initialize
    resource_count = Hash.new(0)
    resource_keep = Array.new
    @resource_state = Hash.new({})
    @config = Hash.new([])
    @message = Hash.new{|h,k|h[k]=Hash.new{|h,k|h[k]=Hash.new{|h,k|h[k]=0}}}
    begin
      @catalog = Puppet::Face[:catalog,'0.0.1'].find(Puppet[:certname])
    rescue => e
      p e
    end
    begin
      @config[:hosts] = @catalog.resource_keys.map do |type, title|
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
        @message[type]['progress']['total'] = resource_count[type]
        @message[type]['progress']['processed'] = 0
        @message[type]['progress']['failed'] = 0
      end
    rescue => e
      p e
      throw Puppet::ParseError
    end
    @config[:hosts]
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
    content = convert_msg(msg)
    time = convert_time(msg.time)
    send_msg(envelope(content,time).to_json) unless content.empty?
  end

  private

  def send_msg(json)
    begin
      JSON.parse(json)
    rescue JSON::ParserError => e
      raise ArgumentError, e.msg
    end
    @config[:targets].each do |target|
      Timeout::timeout(2) do
        connections.publish(target, json)
      end
    end
  end

  def envelope(content,time)
    {
      "host"            => Facter.value("fqdn"),
      "catalog_version" => config_version,
      "time"            => time,
      "content"         => content
    }
  end

  def convert_time(time)
    time.utc.iso8601
  rescue => e
    Puppet.warn(e.message)
    time
  end

  def count_resources(type,title,status)
    return false unless @message.include?(type)
    # State machine!
    if ! @resource_state[type][title] # start state
      case status
      when :err # need to transition to error state and count
        @message[type]['progress']['failed'] += 1
      else # need to transition to nonerror state and count
        @message[type]['progress']['processed'] += 1
      end
      @resource_state[type][title] = status
    else # not in start state
      case @resource_state[type][title]
      when :err # in error state; do nothing
        return false
      else # in nonerror state
        case status
        when :err # transition to error state and count
          @resource_state[type][title] = :err
          @message[type]['progress']['failed'] += 1
          @message[type]['progress']['processed'] -= 1
        else # don't transition; don't count
          return false
        end
      end
    end
    true
  end

  def convert_msg(msg)
    message = Hash.new
    return msg unless msg.respond_to?(:message)
    begin
      message = JSON.parse(msg.message)
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
          if m = msg.source.match(/([^\/]+?)\[([^\[]+?)\](\/[a-z]+)?$/)
            resource_type = m[1].downcase
            resource_title = m[2]
            if count_resources(resource_type,resource_title,msg.level)
              message[resource_type] = @message[resource_type].clone
              message[resource_type]['title'] = resource_title
            end
          end
        rescue => e
          p e
        end
      end
    end
    message
  end
end
