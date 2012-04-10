Puppet::Type.newtype(:progress_resource) do
  @doc = "blank"
  newparam(:resources, :namevar => true, :array_matching => :all) do
    #defaultto(["package"])
    munge do |value|
      Array(value)
    end
  end
end
