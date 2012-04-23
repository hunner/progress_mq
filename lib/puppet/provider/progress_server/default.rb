Puppet::Type.type(:progress_server).provide(:default) do
  desc "Default provider for progress server. Exists to load the progress queue
  log destination"
  def create
    true
  end
  def destroy
    # Cannot ensure => absent
    false
  end
  def exists?
    Puppet.features.progress?
  end
end
