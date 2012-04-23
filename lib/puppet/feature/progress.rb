require 'puppet/util/feature'

Puppet.features.add(:progress) do
  #Puppet::Util::Log.remove_const(:DestQueue) if defined?(Puppet::Util::Log::DestQueue)
  begin
    require 'json'
  rescue LoadError => detail
    require 'rubygems'
    require 'rack'
  end
  require 'puppet/util/log/queue' unless defined?(Puppet::Util::Log::DestQueue)
  if Puppet::Util::Log.newdestination(:queue)
    true
  else
    false
  end
end

