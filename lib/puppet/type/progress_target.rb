Puppet::Type.newtype(:progress_target) do
  @doc = "blank"
  newparam(:targets, :namevar => true, :array_matching => :all) do
    newvalues(/^[a-z\/]+$/)
    munge do |value|
      Array(value)
    end
    #defaultto('/queue/events')
  end
end
