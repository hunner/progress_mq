Puppet::Type.newtype(:progress_server) do
  @doc = "Server to which progress should be reported.

  Designates an MQ server to which JSON-formatted messages are sent via the stomp protocol. Requires instances of both progress_resource to configure resource types to monitor and progress_targets to configure MQ target queues."
  ensurable
  newparam(:name) do
    desc "Title of the server to which we should log."
  end
  newparam(:user) do
    desc "User which has credentials to log to MQ targets."
  end
  newparam(:password) do
    desc "Password of user credentials for MQ."
  end
  newparam(:host) do
    desc "Hostname of MQ server to which we should log."
    newvalues(/^[a-zA-Z0-9\.\-]+$/)
  end
  newparam(:port) do
    desc "Port of MQ server."
    newvalues(/^\d+$/)
  end
  newparam(:ssl) do
    desc "If we should connect to the MQ with SSL. Default: true."
    newvalues(true,false)
    defaultto true
  end
end
