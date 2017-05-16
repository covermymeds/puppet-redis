# == Class: redis::sentinel
#
# Installs redis if its not already and configures the sentinel settings.
#
# === Parameters
#
# $redis_clusters - This is a hash that defines the redis clusters
# $sentinel_conf - The configuration file to read for sentinel
# $sentinel_service - The service to run for sentinel
# that sentinel should watch.
# $protected - As of version 3.2 you need to set proteced-mode yes or no
# or specifically bind to an address, you can use disabled here if
# your versions is installed.
#
# === Examples
#
# class { 'redis::sentinel': }
#
# redis::sentinel::redis_clusters:
#  'claims':
#    master_ip: '192.168.33.51'
#    down_after: 30000
#    failover_timeout: 180000
#  'monkey':
#    master_ip: '192.168.33.54'
#    down_after: 30000
#    failover_timeout: 180000
#
# === Authors
#
# Dan Sajner <dsajner@covermymeds.com>
#
class redis::sentinel (
  $redis_clusters          = undef,
  String $sentinel_conf    = '/etc/sentinel.conf',
  String $sentinel_service = 'sentinel',
  $packages                = ['redis'],
  String $protected        = 'no',
  String $version          = 'installed',
) {

  # Install the redis package
  ensure_packages($packages, { 'ensure' => $version })

  # We need to see what version is in use to see if protected-mode should be set.
  if ( versioncmp( $version, '3.2' ) >= 0 ) or ( $version == 'installed' ) {
    if ( $protected != "disabled" ) {
      $config_32 = $protected
    }
  }

  # Declare $sentinel_conf here so we can manage ownership
  file { $sentinel_conf:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    require => Package[$packages],
  }

  # Sentinel rewrites its config file so we lay this one down initially.
  # This allows us to manage the configuration file upon installation
  # and then never again.
  file { "${sentinel_conf}.puppet":
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0644',
    content => template('redis/sentinel.conf.erb'),
    require => Package[$packages],
  }

  exec { 'cp_sentinel_conf':
    command => "/bin/cp ${sentinel_conf}.puppet ${sentinel_conf} && /bin/touch ${sentinel_conf}.copied",
    creates => "${sentinel_conf}.copied",
    notify  => Service[$sentinel_service],
    require => File["${sentinel_conf}.puppet"],
  }

  # Run it!
  service { $sentinel_service:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => Package[$packages],
  }

  # Lay down the runtime configuration script
  $config_script = '/usr/local/bin/sentinel_config.sh'

  file { $config_script:
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0755',
    content => template('redis/sentinel_config.sh.erb'),
    require => Package[$packages],
    notify  => Exec['configure_sentinel'],
  }

  # Apply the configuration. 
  exec { 'configure_sentinel':
    command     => $config_script,
    refreshonly => true,
    require     => [ Service[$sentinel_service], File[$config_script] ],
  }

}

