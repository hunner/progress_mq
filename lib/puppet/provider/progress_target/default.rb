Puppet::Type.type(:progress_target).provide(:default) do
  desc "Default provider for a progress target. Exists to load the progress queue
  log destination"

  #include Puppet::Provider::Progress
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
