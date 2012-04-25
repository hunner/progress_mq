require 'time'
require 'rubygems'
require 'json'
require 'puppet/face'

Puppet::Util::Log.newdesttype :queue do
  def self.suitable?(obj)
    Puppet.features.stomp?
  end

  def initialize
    @resource_state = Hash.new{|h,k|h[k]=Hash.new{|h,k|h[k]=Hash.new}}
    @progress = Hash.new{|h,k|h[k]=Hash.new{|h,k|h[k]=Hash.new{|h,k|h[k]=0}}}
    true
  end

  def catalog
    @catalog ||= begin
      #Puppet::Face[:catalog,'0.0.1'].find(Puppet[:certname])
      Puppet::Resource::Catalog.indirection.find(Puppet[:certname], :ignore_terminus => true)
    rescue => e
      p e
      p e.backtrace
      nil
    end
  end

  def config
    @config ||= begin
      nil if ! catalog
      resource_count = Hash.new(0)
      resource_list = Hash.new{|h,k|h[k]=Array.new}
      resource_keep = Array.new
      c = Hash.new{|h,k|h[k]=Array.new}
      c[:hosts] = catalog.resource_keys.map do |type, title|
        resource_count[type.downcase] += 1
        resource_list[type.downcase] << title
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
          if resource[:type] == :file
            File.delete(resource[:target])
          end
          nil
        end
      end.compact
      resource_keep.each do |type|
        @progress[type]['progress']['total'] = resource_count[type]
        @progress[type]['progress']['processed'] = 0
        @progress[type]['progress']['skipped'] = 0
        @progress[type]['progress']['failed'] = 0
        @progress[type]['names'] = resource_list[type] unless resource_list[type].empty?
        if Puppet[:evaltrace]
          @progress[type]['progress']['successful'] = 0
        end
      end
      c
    rescue => e
      p e
      p e.backtrace
      throw Puppet::ParseError
    end
  end

  def connections
    return @connections if @connections
    @connections = Stomp::Connection.new({:hosts => config[:hosts]})
    msg = Hash.new{|h,k|h[k]=Hash.new}
    @progress.keys.each do |type|
      msg[type]['names'] = @progress[type]['names'].clone
    end
    Puppet.notice((msg.merge({'puppet_run_status' => 'starting'})).to_json) if @connections
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
      File.open(path, 'a') do |f|
        f.puts json
      end
    rescue => e
      p e
      p e.backtrace
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
    return false unless @progress.include?(type)
    # State machine!
    if ! @resource_state[type][title]['transition'] # start state
      case status
      when :err # need to transition to error state and count
        @progress[type]['progress']['failed'] += 1
        @progress[type]['progress']['processed'] += 1
        @resource_state[type][title]['state'] = 'failed'
      when :skip #need to transition to skip state and count
        @progress[type]['progress']['skipped'] += 1
        @progress[type]['progress']['processed'] += 1
        @resource_state[type][title]['state'] = 'skipped'
      when :eval #need to transition to final state and count
        @progress[type]['progress']['processed'] += 1
        @progress[type]['progress']['successful'] += 1
        @resource_state[type][title]['state'] = 'successful'
        return true
      else # need to transition to nonerror state and count
        @progress[type]['progress']['processed'] += 1
        @resource_state[type][title]['state'] = 'processed'
      end
      @resource_state[type][title]['transition'] = status
      return true unless Puppet[:evaltrace]
    else # not in start state
      case @resource_state[type][title]['transition']
      when :err, :skip # in error or skip state
        case status
        when :eval #transition to final state; don't count
          @resource_state[type][title]['transition'] = :eval
          return true
        else # do nothing
        end
      when :eval
        raise Puppet::Error, "Incorrect state transition for evaltrace"
      else # in nonerror state
        case status
        when :err # transition to error state and count
          @progress[type]['progress']['failed'] += 1
          @resource_state[type][title]['state'] = 'failed'
          @resource_state[type][title]['transition'] = :err
        when :eval #transition to final state and count
          @progress[type]['progress']['successful'] += 1
          @resource_state[type][title]['state'] = 'successful'
          @resource_state[type][title]['transition'] = :eval
          return true
        else # don't transition; don't count
        end
      end
    end
    false
  end

  def convert_msg(msg)
    message = Hash.new{|h,k|h[k]=Hash.new}
    return msg unless msg.respond_to?(:message)
    begin
      message = JSON.parse(msg.message)
    rescue JSON::ParserError => e
      case msg.source
      when 'Puppet'
        case msg.message
        when /Finished catalog run/
          if ! Puppet[:evaltrace]
            @progress.each do |k,v|
              v['progress']['processed'] = v['progress']['total']
            end
          end
          @progress.keys.each do |type|
            message[type] = @progress[type]['progress'].clone
          end
          message = message.merge({'puppet_run_status' => 'finished'})
        when /Not using expired catalog/
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
              message[resource_type]['status'] = @resource_state[resource_type][resource_title]['state']
              message[resource_type]['name'] = resource_title
            end
          end
        rescue => e
          p e
          p e.backtrace
        end
      end
    end
    message
  end
end
