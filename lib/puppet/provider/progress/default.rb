Puppet::Type.type(:progress).provide(:default) do
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
    require 'puppet/util/log/queue' unless defined?(Puppet::Util::Log::DestQueue)
    Puppet::Util::Log.newdestination(:queue)
    #p Puppet::Util::Log.destinations.keys
    @resource_count = Hash.new(0)
    resource.catalog.resource_keys.each do |r|
      @resource_count[r[0].downcase.to_sym] += 1
    end
    p @resource_count
    #p resource.to_resource.methods #to_ral.resources.size
    true
  end
end
