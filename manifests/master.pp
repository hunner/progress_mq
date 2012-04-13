class progress::master {
  include progress::params
  $user      = $progress::params::user
  $host      = $progress::params::host
  $password  = $progress::params::password
  $port      = $progress::params::port
  $ssl       = $progress::params::ssl
  $targets   = $progress::params::targets
  $resources = $progress::params::resources
  # Template uses above variables
  file { '/etc/puppetlabs/puppet/queue.yaml':
    owner   => 'pe-puppet',
    group   => 'pe-puppet',
    mode    => '0640',
    content => template('progress/queue.yaml.erb')
  }
}
