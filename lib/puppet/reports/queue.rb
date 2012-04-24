require 'rubygems'
require 'json'

Puppet::Reports.register_report(:queue) do
  desc "Send final report statistics and resource statuses to MQ server."
  def process
    return unless Puppet.features.stomp?
    configfile = File.join(Puppet[:confdir], "queue.yaml")
    raise(Puppet::ParseError, "Queue report config file #{configfile} not readable") unless File.exist?(configfile)
    config = YAML.load_file(configfile)
    # convert all the keys of each host entry to symbols
    begin
      config["hosts"] = config["hosts"].map{|h|h.reduce({}){|h,(k,v)|h[k.to_sym]=v;h}}
      config["targets"] = config["targets"].delete_if { |k,v|
        v['type'] and v['type'] =~ /^file/
      }.keys
      send_msg(config["hosts"], config["targets"], report.to_json)
    rescue => e
      p e
    end
  end

  def send_msg(hosts, targets, json)
    Timeout::timeout(2) do
      connections = Stomp::Connection.new({:hosts => hosts})
      targets.each do |target|
        connections.publish(target, json)
      end
    end
  end

  def report
    r = {}
    r['status'] = status
    r['configuration_version'] = configuration_version
    r['metrics'] = Hash.new
    r['metrics']['total'] = metrics['time']['total']
    r['metrics']['config_retrieval'] = metrics['time']['config_retrieval']
    r['resource_statuses'] = Hash.new{|h,k|h[k]=[]}
    resource_statuses.each do |id,value|
      if value.failed
        r['resource_statuses']['failed'] << { 'resource' => id }
      else
        if value.evaluation_time
          r['resource_statuses']['successful'] << { 'resource' => id, 'time' => value.evaluation_time }
        else
          r['resource_statuses']['successful'] << { 'resource' => id }
        end
      end
    end
    r
  end
end
