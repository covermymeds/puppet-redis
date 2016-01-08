# == Class: redis
#
# Installs and configures redis.
#
# === Parameters
#
# $config: A hash of Redis config options to apply at runtime
# $version: The package version of Redis you want to install 
#
# === Examples
#
# $config_hash = { 'dir'       => '/pub/redis',
#                  'maxmemory' => '1073741824',
#                  'slaveof'   => '10.1.1.52',
#                }
#
# class { redis:
#   config  => $config_hash
# }
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
#
class redis (
  $config  = {},
  $version = 'installed',
) {

  # Install the redis package
  ensure_packages(['redis'], { 'ensure' => $version })

  # Define the data directory with proper ownership if provided
  if ! empty($config['dir']) {
    file { $config['dir']:
      ensure  => directory,
      owner   => 'redis',
      group   => 'redis',
      require => Package['redis'],
      before  => Exec['configure_redis'],
    }
  }

  # Declare /etc/redis.conf so that we can manage the ownership
  file { '/etc/redis.conf':
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    require => Package['redis'],
  }

  # Run it!
  service { 'redis':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => Package['redis'],
  }

  # Lay down the configuration script,  Content based on the config hash.
  $config_script = '/usr/local/bin/redis_config.sh'

  file { $config_script:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0755',
    content => template('redis/redis_config.sh.erb'),
    require => Package['redis'],
    notify  => Exec['configure_redis'],
  }
    
  # The config script will touch this file if redis is down when it tries to run.
  # Ensuring that it is absent allows puppet to retry the configuration step.
  file { '/var/cache/CONFIGUREREDIS':
    ensure => absent,
    notify => Exec['configure_redis'],
  }

  # Apply the configuration. 
  exec { 'configure_redis':
    command     => $config_script,
    refreshonly => true,
    require     => [ Service['redis'], File[$config_script] ],
  }

}
