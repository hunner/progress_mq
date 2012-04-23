require 'time'
require 'rubygems'
require 'json'
require 'puppet/face'

Puppet::Util::Log.newdesttype :queue do
  def self.suitable?(obj)
    Puppet.features.stomp?
  end

  def initialize
    @resource_state = Hash.new({})
    @message = Hash.new{|h,k|h[k]=Hash.new{|h,k|h[k]=Hash.new{|h,k|h[k]=0}}}
    true
  end

  def catalog
    @catalog ||= begin
      #Puppet::Face[:catalog,'0.0.1'].find(Puppet[:certname])
      Puppet::Resource::Catalog.indirection.find(Puppet[:certname], :ignore_terminus => true)
    rescue => e
      p e
      nil
    end
  end

  def config
    @config ||= begin
      nil if ! catalog
      resource_count = Hash.new(0)
      resource_keep = Array.new
      c = Hash.new([])
      c[:hosts] = catalog.resource_keys.map do |type, title|
        resource_count[type.downcase] += 1
        resource = catalog.resource("#{type}[#{title}]").to_ral
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
          c[:targets] << {
            'target' => resource[:target],
            'type'   => resource[:type],
          }
          nil
        end
      end.compact
      resource_keep.each do |type|
        @message[type]['progress']['total'] = resource_count[type]
        @message[type]['progress']['processed'] = 0
        @message[type]['progress']['skipped'] = 0
        @message[type]['progress']['failed'] = 0
        if Puppet[:evaltrace]
          @message[type]['progress']['successful'] = 0
        end
      end
      c
    rescue => e
      p e
      throw Puppet::ParseError
    end
  end

  def connections
    return @connections if @connections
    @connections = Stomp::Connection.new({:hosts => config[:hosts]})
    Puppet.notice((@message.merge({'puppet_run_status' => 'starting'})).to_json) if @connections
    @connections
  end

  def config_version
    @config_version ||= catalog.version
  end

  def handle(msg)
    content = convert_msg(msg)
    time = convert_time(msg.time)
    if content and ! content.empty?
      break if ! config
      message = envelope(content,time).to_json
      config[:targets].each do |target|
        case target['type']
        when :file, :file_append
          write_msg(target['type'],target['target'],message)
        when :queue
          send_msg(target['target'],message)
        else
          raise Puppet::Error, "Incorrect 'type' value for #{target['target']}"
        end
      end
    end
  end

  private

  def send_msg(target,json)
    begin
      JSON.parse(json)
    rescue JSON::ParserError => e
      raise ArgumentError, e.msg
    end
    Timeout::timeout(2) do
      connections.publish(target, json)
    end
  end

  def write_msg(type, path, json)
    begin
      mode = type == :file_append ? 'a' : 'w'
      File.open(path, mode) do |f|
        f.puts json
      end
    rescue => e
      p e
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
        @message[type]['progress']['processed'] += 1
      when :skip #need to transition to skip state and count
        @message[type]['progress']['skipped'] += 1
        @message[type]['progress']['processed'] += 1
      when :eval #need to transition to final state and count
        @message[type]['progress']['processed'] += 1
        @message[type]['progress']['successful'] += 1
        return true
      else # need to transition to nonerror state and count
        @message[type]['progress']['processed'] += 1
      end
      @resource_state[type][title] = status
      return true unless Puppet[:evaltrace]
    else # not in start state
      case @resource_state[type][title]
      when :err, :skip # in error or skip state
        case status
        when :eval #transition to final state; don't count
          @resource_state[type][title] = :eval
          return true
        else # do nothing
        end
      when :eval
        raise Puppet::Error, "Incorrect state transition for evaltrace"
      else # in nonerror state
        case status
        when :err # transition to error state and count
          @resource_state[type][title] = :err
          @message[type]['progress']['failed'] += 1
        when :eval #transition to final state and count
          @message[type]['progress']['successful'] += 1
          @resource_state[type][title] = :eval
          return true
        else # don't transition; don't count
        end
      end
    end
    false
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
          if ! Puppet[:evaltrace]
            @message.each do |k,v|
              v['progress']['processed'] = v['progress']['total']
            end
          end
          message = @message.merge({'puppet_run_status' => 'finished'})
        when /Not using expired catalog/
          p "skipping msg"
          return nil
        end
      when /.+\/.+/
        begin
          break if ! config
          if m = msg.source.match(/(([^\/]+?)\[([^\[]+?)\])(\/[a-z]+)?$/)
            resource_name = m[1]
            resource_type = m[2].downcase
            resource_title = m[3]
            level = :skip if msg.message =~ /^Dependency \S+ has failures: true$/
            level = :eval if msg.message =~ /^Evaluated in [\d\.]+ seconds$/
            if count_resources(resource_type,resource_title,level || msg.level)
              message[resource_type] = @message[resource_type].clone
              message['resource'] = resource_name
              message['type'] = resource_type
              message['title'] = resource_title
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
