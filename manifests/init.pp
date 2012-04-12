class progress(
  $user,
  $host,
  $password,
  $port,
  $ssl = true,
  $targets = '/queue/events',
  $resources
) {
  stage { 'progress':
    before => Stage['main'],
  }
  class { 'progress::params':
    user      => $user,
    host      => $host,
    password  => $password,
    port      => $port,
    ssl       => $ssl,
    targets   => $targets,
    resources => $resources,
    stage     => 'progress',
  }
  class { 'progress::queue':
    stage => 'progress',
  }
}
