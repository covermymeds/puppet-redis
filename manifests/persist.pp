# == Class: redis::persist
#
# Managed data persistence settings for master and slaves.
# This class should not be explicitly declared.
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
#
class redis::persist (
  $manage_persistence = $redis::manage_persistence,
) {

  $ensure = $manage_persistence ? {
    true  => 'present',
    false => 'absent',
  }

  $config_script = '/usr/local/bin/redis_persist.sh'

  # Provide a script to check state and reconfigure redis
  # as needed.
  file { $config_script:
    ensure  => $ensure,
    owner   => 'redis',
    group   => 'root',
    mode    => '0755',
    source  => 'puppet:///modules/redis/redis_persist.sh',
    require => Package['redis'],
  }

  # Run a cron every minute to monitor the redis role and execute
  # $config_script if the role has changed.
  cron { 'redis persistence':
    ensure  => $ensure,
    command => $config_script,
    hour    => '*',
    minute  => ['0-59'],
    require => File[ $config_script ],
  }

}
