class progress::queue {
  include progress::params
  progress_server { "queue":
    ensure   => 'present',
    user     => $progress::params::user,
    host     => $progress::params::host,
    password => $progress::params::password,
    port     => $progress::params::port,
    ssl      => $progress::params::ssl,
  }
  progress_resource { $progress::params::resources: }
  progress_target { $progress::params::targets: }
}
