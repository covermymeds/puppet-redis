# == Class: redis
#
# Installs and configures redis.
#
# === Parameters
#
# $config: A hash of Redis config options to apply at runtime
# $manage_persistence: Boolean flag for including the redis::persist class
# $slaveof: IP address of the initial master Redis server 
# $version: The package version of Redis you want to install 
#
# === Examples
#
# $config_hash = { 'dir' => '/pub/redis', 'maxmemory' => '1073741824' }
#
# class { redis:
#   config  => $config_hash
#   slaveof => '192.168.33.10'
# }
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
#
class redis (
  $config             = {},
  $manage_persistence = false,
  $slaveof            = undef,
  $version            = 'installed',
  $disable_thp        = true,
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

  # Lay down intermediate config file and copy it in with a 'cp' exec resource.
  # Redis rewrites its config file with additional state information so we only
  # want to do this the first time redis starts so we can at least get it 
  # daemonized and assign a master node if applicable.
  file { '/etc/redis.conf.puppet':
    ensure  => present,
    owner   => redis,
    group   => root,
    mode    => '0644',
    content => template('redis/redis.conf.puppet.erb'),
    require => Package['redis'],
  }

  exec { 'cp_redis_config':
    command => '/bin/cp -p /etc/redis.conf.puppet /etc/redis.conf && /bin/touch /etc/redis.conf.copied',
    creates => '/etc/redis.conf.copied',
    require => File['/etc/redis.conf.puppet'],
    notify  => Service[redis],
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

  # In an HA setup we choose to only persist data to disk on
  # the slaves for better performance.
  include redis::persist

  # Redis docs recommend disabling transparent huge pages
  # http://redis.io/topics/latency
  if $disable_thp {
    exec { "disable_transparent_hugepage_enabled":
      command => '/bin/echo never > /sys/kernel/mm/transparent_hugepage/enabled',
      unless  => '/bin/grep -c \'\[never\]\' /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null',
      notify  => Service['redis']
    }
  }

}
