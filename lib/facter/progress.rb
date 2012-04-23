Facter.add(:progress) do
  setcode do
    Puppet.features.progress?
  end
end
