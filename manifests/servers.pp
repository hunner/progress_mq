class progress::servers (
  $servers = false,
  $targets = false,
  $resources = false
) {
  if $servers and $servers != {} {
    $progress_servers = $servers
  } else {
    $progress_servers = hiera_array('progress_servers')
  }
  if $targets {
    $progress_targets = $targets
  } else {
    $progress_targets = hiera_array('progress_targets')
  }
  if $resources {
    $progress_resources = $resources
  } else {
    $progress_resources = hiera_array('progress_resources')
  }
  create_resources('progress_server', $progress_servers)
  progress_resource { $progress_resources: }
  progress_target { $progress_targets: }
}
