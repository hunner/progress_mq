class progress::queue {
  progress_server { "queue":
    ensure   => 'present',
    user     => 'mcollective',
    host     => 'training.puppetlabs.lan',
    password => '3RQTuUM41Gq97EjFNxxa',
    port     => 61613,
    ssl      => true,
  }
  progress_resource { 'notify': }
  progress_target { '/queue/events': }
}
