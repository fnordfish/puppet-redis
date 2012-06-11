# == Class: redis
#
# Install and configure redis.
#
# === Parameters
#
# [*redis_src_dir*]
#   Location to unpack source code before building and installing it.
#   Default: /tmp
#
# [*redis_bin_dir*]
#   Location to install redis binaries. (PREFIX)
#   Default: /usr/local
#
# [*redis_max_memory*]
#   Set the redis config value maxmemory (bytes).
#   Default: 4gb
#
# [*redis_max_clients*]
#   Set the redis config value maxclients.
#   Default: 0
#
# [*redis_timeout*]
#   Set the redis config value timeout (seconds).
#   Default: 300
#
# [*redis_loglevel*]
#   Set the redis config value loglevel. Valid values are debug,
#   verbose, notice, and warning.
#   Default: notice
#
# [*redis_databases*]
#   Set the redis config value databases.
#   Default: 16
#
# [*redis_slowlog_log_slower_than*]
#   Set the redis config value slowlog-log-slower-than (microseconds).
#   Default: 10000
#
# [*redis_showlog_max_len*]
#   Set the redis config value slowlog-max-len.
#   Default: 1024
#
# === Examples
#
# include redis
#
# === Authors
#
# Thomas Van Doren
#
# === Copyright
#
# Copyright 2012 Thomas Van Doren, unless otherwise noted.
#
class redis (
  $redis_bin_dir = '/usr/local',     # aka PREFIX
  $redis_src_dir = '/tmp',
  $redis_port = '6379',
  $redis_max_memory = '4gb',
  $redis_max_clients = 0,            # 0 = unlimited
  $redis_timeout = 300,              # 0 = disabled
  $redis_loglevel = 'notice',
  $redis_databases = 16,
  $redis_slowlog_log_slower_than = 10000, # microseconds
  $redis_slowlog_max_len = 1024
  ) {

  $redis_src = "${redis_src_dir}/redis-2.4.14"
  $redis_pkg = "${redis_src_dir}/redis-2.4.14.tar.gz"

  $redis_init_file   = "/etc/init.d/redis_${redis_port}"
  $redis_config_file = "/etc/redis/${redis_port}.conf"
  $redis_log_file    = "/var/log/redis_${redis_port}.log"
  $redis_data_dir    = "/var/lib/redis/${redis_port}"
  $redis_executable  = "$redis_bin_dir/bin/redis-server"

  File {
    owner => root,
    group => root,
  }

  file { 'redis-pkg':
    ensure => present,
    path   => $redis_pkg,
    mode   => '0644',
    source => 'puppet:///modules/redis/redis-2.4.14.tar.gz',
  }

  file {'redis-server-installer':
    ensure => present,
    path   => "$redis_src/utils/install_server.sh",
    mode   => '0775',
    source => 'puppet:///modules/redis/install_server.sh',
    require => Exec['unpack-redis'],
  }

  if !defined(Package['build-essential']) {
    package {'build-essential':
      ensure => present,
    }
  }

  exec { 'unpack-redis':
    command => "tar -xzf ${redis_pkg}",
    cwd     => $redis_src_dir,
    creates => $redis_src,
    path    => '/bin:/usr/bin',
    unless  => "test -f ${redis_src_dir}/Makefile",
    require => File['redis-pkg'],
  }

  exec { 'install-redis':
    command => "make && make install PREFIX=${redis_bin_dir}",
    cwd     => $redis_src,
    path    => '/bin:/usr/bin',
    unless  => "test $(${redis_bin_dir}/bin/redis-server --version | cut -d ' ' -f 1) = 'Redis'",
    require => [ Exec['unpack-redis'],
                 Package['build-essential'],
                 ],
  }

  exec { 'install-redis-server':
    command => "echo 'REDIS_PORT=\"${redis_port}\" REDIS_CONFIG_FILE=\"${redis_config_file}\" REDIS_LOG_FILE=\"${redis_log_file}\" REDIS_DATA_DIR=\"${redis_data_dir}\" REDIS_EXECUTABLE=\"${redis_executable}\" ${redis_src}/utils/install_server.sh' | bash -s",
    cwd     => "${redis_src}/utils",
    path    => '/bin:/sbin:/usr/bin:/usr/sbin',
    unless  => "test -f /etc/init.d/redis_6379",
    logoutput => true,
    require => [Exec['install-redis'], File['redis-server-installer']],
  }

  service { 'redis':
    ensure    => running,
    name      => 'redis_6379',
    enable    => true,
    require   => Exec['install-redis-server'],
  }
}
