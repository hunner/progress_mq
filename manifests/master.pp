# = Class: progress::master
#
# This class sets up the MQ report processor on a Puppet master. This class is
# set up to work either directly, or with Hiera.
#
# == Parameters:
#
# $servers:: This attribute is a hash of MQ server settings to which the
#            report processor may log. Each server hash is composed of the
#            following keys: $user, $host, $password, $port, $ssl and is used to
#            create the configuration file. May be declared in Hiera as
#            $progress_servers.
#
# $targets:: The target queues or files to which progress should be logged. Must
#            be a hash. May be declared in Hiera as $progress_targets.
#
# == Actions:
#   Places configuration file for queue report processor.
#
# == Requires:
#   - JSON ruby gem
#   - STOMP ruby gem
#
# == Sample Usage:
#   # If you have Hiera:
#   include progress::master
#
#   # Otherwise:
#   class { 'progress::master':
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
#     },
#   }
#
class progress::master (
  $servers = hiera_hash('progress_servers'),
  $targets = hiera_hash('progress_targets',{'/queue/events' => {}})
) {
  file { '/etc/puppetlabs/puppet/queue.yaml':
    owner   => 'pe-puppet',
    group   => 'pe-puppet',
    mode    => '0640',
    content => template('progress/queue.yaml.erb')
  }
}
