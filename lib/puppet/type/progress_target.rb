Puppet::Type.newtype(:progress_target) do
  @doc = "Log progress to specified queue targets; requires progress_server.

  Example:
  progress_target { '/queue/progress': }"
  newparam(:targets, :namevar => true, :array_matching => :all) do
    desc "String or array of targets to log to."
    newvalues(/^[a-z\/_]+$/)
    munge do |value|
      Array(value)
    end
  end
end
