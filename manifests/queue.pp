class progress::queue {
  progress { "queue":
    ensure   => 'present',
    user     => 'mcollective',
    host     =>  'training.puppetlabs.lan',
    password =>  '3RQTuUM41Gq97EjFNxxa',
    port     =>  61613,
    ssl      =>  true,
    types    => ['notify'],
    target   =>  '/queue/events',
  }
}
