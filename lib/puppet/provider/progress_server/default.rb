Puppet::Type.type(:progress_server).provide(:default) do
  desc "Default provider for progress server. Exists to load the progress queue
  log destination"
  def create
    true
  end
  def destroy
    # Cannot ensure => absent
    false
  end
  def exists?
    #Puppet::Util::Log.remove_const(:DestQueue) if defined?(Puppet::Util::Log::DestQueue)
    require 'rubygems'
    require 'json'
    require 'puppet/util/log/queue' unless defined?(Puppet::Util::Log::DestQueue)
    Puppet::Util::Log.newdestination(:queue)
    true
  end
end
