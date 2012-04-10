Puppet::Type.type(:progress_server).provide(:default) do
  desc "This is a default provider that does nothing."
  def create
    true
  end
  def destroy
    true
  end
  def exists?
    #fail('This is just the default provider all it does is fail')
    #Puppet::Util::Log.remove_const(:DestQueue) if defined?(Puppet::Util::Log::DestQueue)
    require 'json'
    require 'puppet/util/log/queue' unless defined?(Puppet::Util::Log::DestQueue)
    Puppet::Util::Log.newdestination(:queue)
    #Puppet.notice({"resource_count" => @resource_count}.to_json)
    true
  end
end
