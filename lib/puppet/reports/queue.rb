require 'rubygems'
require 'json'

Puppet::Reports.register_report(:queue) do
  desc "document the report"
  def process
    return unless Puppet.features.stomp?
    #Puppet::Face[:catalog, '0.0.1'].set_terminus :yaml
    #Puppet::Face[:catalog, '0.0.1'].set_terminus("yaml")
    #catalog = Puppet::Face[:catalog, '0.0.1'].find(host)
    #require 'ruby-debug' ; debugger ; 1
    # report logic goes here

    configfile = File.join(Puppet[:confdir], "queue.yaml")
    raise(Puppet::ParseError, "Queue report config file #{configfile} not readable") unless File.exist?(configfile)
    config = YAML.load_file(configfile)
    # convert all the keys of each host entry to symbols
    config['hosts'] = config['hosts'].map{|h|h.reduce({}){|h,(k,v)|h[k.to_sym]=v;h}}
    #puts JSON.pretty_generate(report)
    #require 'ruby-debug' ; debugger ; 1
    #hosts = progress_servers.collect do |resource|
    #  {
    #    :login    => resource[:user],
    #    :passcode => resource[:password],
    #    :host     => resource[:host],
    #    :port     => resource[:port],
    #    :ssl      => resource[:ssl],
    #  }
    #end
    #p hosts
    #targets = progress_targets.collect do |resource|
    #  resource[:targets]
    #end
    #p targets
    send_msg(config['hosts'], config['targets'], report.to_json)
  end

  def send_msg(hosts, targets, json)
    Timeout::timeout(2) do
      connections = Stomp::Connection.new({:hosts => hosts})
      targets.each do |target|
        connections.publish(target, json)
      end
    end
  end

  def progress_servers
    catalog_search('progress_server')
  end

  def progress_targets
    catalog_search('progress_target')
  end

  def catalog_search(type)
    #catalog.filter { |res| res.type.downcase != type.downcase }
    catalog.resources.reject { |res|
      res.type.downcase != type.downcase
    }.map { |res|
      res.to_ral
    }
  end

  def catalog
    if @catalog
      return @catalog
    else
      Puppet::Resource::Catalog.indirection.cache_class = :yaml
      @catalog = Puppet::Resource::Catalog.indirection.find(host) #, :ignore_terminus => true)
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
