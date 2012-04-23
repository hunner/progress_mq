Puppet::Type.newtype(:progress_target) do
  @doc = "Log progress to specified queue targets; requires progress_server.

  Examples:
  progress_target { '/queue/progress': }
  progress_target { '/var/log/progress.json': type => 'file', }"

  newparam(:target, :namevar => true) do
    desc "MQ or file target to log to, depending on target type."
  end
  newparam(:type) do
    desc "Type of target."
    defaultto('queue')
    newvalues('queue','file','file_append')
  end
end
