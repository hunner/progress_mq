Puppet::Type.newtype(:progress) do
  #p Puppet::Util::Log.desttypes
  #require 'puppet/util/log/queue'
  #p Puppet::Util::Log.desttypes
  @doc = "blank"
  ensurable
  newparam(:name)
  newparam(:user)
  newparam(:password)
  newparam(:host) do
    newvalues(/^[a-zA-Z0-9\.\-]+$/)
  end
  newparam(:port) do
    newvalues(/^\d+$/)
  end
  newparam(:ssl) do
    newvalues(:true,:false)
    defaultto :true
    munge do |value|
      if value == :true
        true
      else
        false
      end
    end
  end
  newparam(:types, :array_matching => :all) do
    defaultto(["package"])
    munge do |value|
      Array(value)
    end
  end
  newparam(:target) do
    newvalues(/^[a-z\/]+$/)
    defaultto('/queue/events')
  end
end
