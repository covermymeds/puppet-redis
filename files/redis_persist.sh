#!/bin/bash
#
# redis_persist.sh - Update persistence settings based on role
#
function reconfig_redis() {
  if [[ "$1" = "master"* ]]; then
    # Configure for no persistence
    $redis_cli config set save ""
    $redis_cli config set appendonly "no"
    $redis_cli config rewrite
    echo "$1" > $cache_file
  elif [[ "$1" = "slave"* ]]; then
    # Configure for persistence
    $redis_cli config set save "900 1 300 10 60 10000"
    $redis_cli config set appendonly "yes"
    $redis_cli config rewrite
    echo "$1" > $cache_file
  else
    echo "Unknown redis role: $1"
  fi
}

redis_cli='/usr/bin/redis-cli'
cache_file='/var/cache/redis_role'
role=$(${redis_cli} info | grep role | awk -F':' '{print $2}' | tr -d '[[:space:]]')

if [ -f $cache_file ]; then
  if [ "$role" != "$(cat ${cache_file} | tr -d '[[:space:]]')" ]; then
    reconfig_redis $role
  fi
else
  reconfig_redis $role
  echo "$role" > $cache_file
fi
