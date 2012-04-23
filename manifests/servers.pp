class progress::servers (
  $servers = false,
  $targets = false,
  $resources = false
) {
  if $servers and $servers != {} {
    $progress_servers = $servers
  } else {
    $progress_servers = hiera_hash('progress_servers')
  }
  if $targets {
    $progress_targets = $targets
  } else {
    $progress_targets = hiera_hash('progress_targets')
  }
  if $resources {
    $progress_resources = $resources
  } else {
    $progress_resources = hiera_array('progress_resources')
  }
  if $progress_servers {
    create_resources('progress_server', $progress_servers)
  }
  if $progress_targets {
    create_resources('progress_target', $progress_targets)
    #notice("${progress_targets}")
  }
  if $progress_resources {
    progress_resource { $progress_resources: }
  }
}
