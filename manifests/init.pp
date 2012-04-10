class progress {
  stage { 'progress':
    before => Stage['main'],
  }
  class { 'progress::queue':
    stage => 'progress',
  }
}
