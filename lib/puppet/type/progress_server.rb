Puppet::Type.newtype(:progress_server) do
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
    newvalues(true,false)
    defaultto true
  end
end
