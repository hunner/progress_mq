Puppet::Type.newtype(:progress_resource) do
  @doc = "Monitor the progress of specified resource types; requires progress_server.

  Example:
  progress_resource { ['package','service']: }"
  newparam(:resources, :namevar => true, :array_matching => :all) do
    desc "String or array of resources to monitor."
    munge do |value|
      Array(value)
    end
  end
end
