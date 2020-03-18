# == Class: redis
#
# Installs and configures redis.
#
# === Parameters
#
# $config: A hash of Redis config options to apply at runtime
# $manage_persistence: Boolean flag for including the redis::persist class
# $slaveof: IP address of the initial master Redis server (Being deprecated)
# $version: The package version of Redis you want to install
# $packages: The packages needed to install redis
# $redis_conf: The configuration file for redis
# $service_name: The serivce to run for redis
# $protected - As of version 3.2 you need to set proteced-mode yes or no
# or specifically bind to an address, if you are using an earlier
# version of redis and "installed" as your version you can use "protected = disabled"
# to make sure the option protected-mode is not added to the configuration fie.
# $use_scl_redis: flag to indicate if Redis package is from Software Collections
# $scl_redis_name: the SCL package name for Redis. Note this is different from $packages
#                  (e.g. $scl_redis_name = "rh-redis5", $packages=['rh-redis5-redis'])
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
  $config               = {},
  $manage_persistence   = false,
  $slaveof              = undef,
  $use_scl_redis        = false,
  $scl_redis_name       = undef,
  $packages             = ['redis'],
  String $protected     = 'yes',
  String $redis_conf    = '/etc/redis.conf',
  String $service_name  = 'redis',
  String $version       = 'installed',
) {

  # Install the redis package
  ensure_packages($packages, { 'ensure' => $version })

  # See if protected-mode should be set.
  if ( versioncmp( $version, '3.2' ) >= 0 ) or ( $version == 'installed' ) {
    if ( $protected != "disabled" ) {
      $config_32 = $protected
    }
  }

  # Define the data directory with proper ownership if provided
  if ! empty($config['dir']) {
    file { $config['dir']:
      ensure  => directory,
      owner   => 'redis',
      group   => 'redis',
      require => Package[$packages],
      before  => Exec['configure_redis'],
    }
  }

  # Declare /etc/redis.conf so that we can manage the ownership
  file { $redis_conf:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    require => Package[$packages],
  }

  if $use_scl_redis and ! empty($scl_redis_name) {
    file {'/etc/redis.conf':
      ensure => link,
      target => $redis_conf,
    }

    file {"/etc/profile.d/${scl_redis_name}-enable.sh":
      ensure  => link,
      target  => "/opt/rh/${scl_redis_name}/enable",
      require => Package[$packages],
    }

    file {'/usr/bin/redis-cli':
      ensure  => link,
      target  => "/opt/rh/${scl_redis_name}/root/usr/bin/redis-cli",
      require => Package[$packages],
    }
  }

  $conf_template = $use_scl_redis ? {
    true  => 'redis/redis5.conf.puppet.erb',
    false => 'redis/redis.conf.puppet.erb'
  }

  # Lay down intermediate config file and copy it in with a 'cp' exec resource.
  # Redis rewrites its config file with additional state information so we only
  # want to do this the first time redis starts so we can at least get it
  # daemonized and assign a master node if applicable.
  file { "${redis_conf}.puppet":
    ensure  => present,
    owner   => redis,
    group   => root,
    mode    => '0644',
    content => template($conf_template),
    require => Package[$packages],
  }

  exec { 'cp_redis_config':
    command => "/bin/cp -p ${redis_conf}.puppet ${redis_conf} && /bin/touch ${redis_conf}.copied",
    creates => "${redis_conf}.copied",
    require => File["${redis_conf}.puppet"],
    notify  => Service[$service_name],
  }

  # Run it!
  service { $service_name:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => Package[$packages],
  }

  # Lay down the configuration script,  Content based on the config hash.
  $config_script = '/usr/local/bin/redis_config.sh'

  file { $config_script:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0755',
    content => template('redis/redis_config.sh.erb'),
    require => Package[$packages],
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
    require     => [ Service[$service_name], File[$config_script] ],
  }

  # In an HA setup we choose to only persist data to disk on
  # the slaves for better performance.
  include redis::persist

}
