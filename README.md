# puppet-redis
This module provides configuration management for Redis and Sentinel.  This module aims to properly manage Redis setups that use Sentinel for the HA management.

This module is different than most available on the Forge in that it manages most of the Redis configuration using the redis-cli against the running instance.  We took this approach because Redis by design persists state information to its own configuration file (http://redis.io/commands/config-rewrite).  This makes management of `/etc/redis.conf` and `/etc/sentinel.conf` just about impossible for HA setups.

# Provisos
1. Requires Redis 2.8.0 or later.
2. Assumes that Redis is available via a standard package install.

# Usage
Install the latest available version of Redis with default configs (defaults provided in the template anyhow)
```
class { 'redis': }
```

Install Redis and configure as a slave.  Manage some other configuration including persistence.
```
$config_hash = { 'dir' => '/pub/redis', 'maxmemory' => '1073741824' }

class { 'redis':
  config             => $config_hash,
  manage_persistence => true,
  slaveof            => '192.168.33.10',
}
```

Install and configure Sentinel to manage 2 independent Redis Master/Slave setups. (Sentinel discovers the other slaves.)
```
$redis_clusters = { 'cluster1' => { 'master_ip' => '192.168.33.51',
                                    'down_after' => '30000',
                                    'failover_timeout' => '180000' },
                    'cluster2' => { 'master_ip' => '192.168.33.54',
                                    'down_after' => '30000',
                                    'failover_timeout' => '180000' },
                  }

class { 'sentinel':
  redis_clusters => $redis_clusters,
}
```

# Notes
The service definition is only dependent on the package so Redis may start with the configuration installed via your package.  The initial config file overlay will notify the Redis server to restart so upon initial installation Redis may start and then restart with updated configs.  In testing this has not presented any issues.




