# = Class: progress
#
# This class sets up the MQ servers, MQ targets, and resources to watch for
# progression reporting of a puppet run. This class is set up to work either
# directly, or with Hiera.
#
# == Parameters:
#
# $servers:: This attribute is a hash of MQ server settings to which the
#            progress reporter may log. Each server hash is composed of the
#            following keys: $user, $host, $password, $port, $ssl and is used to
#            declare progress_server resources. May be declared in Hiera as
#            $progress_servers.
#
# $targets:: The target queues or files to which progress should be logged. Must
#            be a hash where the key is the resource title and the value hash is
#            the attributes. May be declared in Hiera as $progress_targets. See
#            `puppet describe progress_target` for available hash values.
#
# $resources:: The resources of which to track the progress. May be a string or
#              an array.
#
# == Actions:
#   Configures the progress logging destination from the catalog in memory.
#
# == Requires:
#   - JSON ruby gem
#   - STOMP ruby gem
#
# == Sample Usage:
#   # If you have Hiera:
#   include progress
#
#   # Otherwise:
#   class { 'progress':
#     servers   => {
#       'example server' => {
#         host     => 'stomp.example.com',
#         user     => 'mq_user',
#         password => 'mq_user_password',
#       },
#     },
#     targets   => {
#       '/queue/progress'        => {},
#       '/var/log/progress.json' => {
#         'type' => 'file'
#       },
#       '/var/log/progress_append.json' => {
#         'type' => 'file_append'
#       },
#     },
#     resources => [
#       'package',
#       'service',
#     ],
#   }
#
class progress (
  $servers = {},
  $targets = {'/queue/progress' => {}},
  $resources = "package"
) {
  class { 'progress::servers':
    servers   => $servers,
    targets   => $targets,
    resources => $resources,
  }
}
