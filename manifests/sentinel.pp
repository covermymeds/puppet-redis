# == Class: redis::sentinel
#
# Installs redis if its not already and configures the sentinel settings.
#
# === Parameters
#
# $redis_clusters - This is a hash that defines the redis clusters
# that sentinel should watch.
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
  $version        = 'installed',
  $redis_clusters = undef,
) {

  # Install the redis package
  ensure_packages(['redis'], { 'ensure' => $version })

  # Declare /etc/sentinel.conf here so we can manage ownership
  file { '/etc/sentinel.conf':
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    require => Package['redis'],
  }

  # Sentinel rewrites its config file so we lay this one down to manage changes.
  # This allows us to manage configuration changes without rewriting the
  # file on every Puppet run.
  file { '/etc/sentinel.conf.puppet':
    ensure  => present,
    owner   => 'redis',
    group   => 'root',
    mode    => '0644',
    content => template('redis/sentinel.conf.erb'),
    require => Package['redis'],
    notify  => Exec['cp_sentinel_conf'],
  }

  exec { 'cp_sentinel_conf':
    command     => '/bin/cp /etc/sentinel.conf.puppet /etc/sentinel.conf',
    refreshonly => true,
    notify      => Service[sentinel],
  }

  # Run it!
  service { 'sentinel':
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
    require    => Package['redis'],
  }

}

