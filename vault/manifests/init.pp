class vault (
  String  $user             = lookup('vault::user'),
  Boolean $manage_user      = lookup('vault::manage_user'),
  String  $group            = lookup('vault::group'),
  Boolean $manage_group     = lookup('vault::manage_group'),
  String  $config_dir       = lookup('vault::config_dir'),
  Boolean $purge_config_dir = lookup('vault::purge_config_dir'),
  String  $service_name     = lookup('vault::service_name'),
  Boolean $service_enable   = lookup('vault::service_enable'),
  String  $version          = lookup('vault::version'),
  String  $download_url     = lookup('vault::download_url'),
  String  $install_dir      = lookup('vault::install_dir'),
  String  $listen_address   = lookup('vault::listen_address'),
  Integer $listen_port      = lookup('vault::listen_port'),
  Boolean $ui_enabled       = lookup('vault::ui_enabled'),
  Boolean $tls_disable      = lookup('vault::tls_disable'),
  Boolean $disable_mlock    = lookup('vault::disable_mlock'),
) {

  group { $group:
    ensure => present,
  }

  user { $user:
    ensure     => present,
    managehome => $manage_user,
    gid        => $group,
    require    => Group[$group],
  }

  package { 'unzip':
    ensure => present,
  }

  exec { 'download-vault':
    command => "/usr/bin/curl -sL -o /tmp/vault_${version}.zip ${download_url}",
    creates => "/tmp/vault_${version}.zip",
  }

  exec { 'extract-vault':
    command => "/usr/bin/unzip -o /tmp/vault_${version}.zip -d ${install_dir}",
    creates => "${install_dir}/vault",
    require => [Exec['download-vault'], Package['unzip']],
  }

  file { "${install_dir}/vault":
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    require => Exec['extract-vault'],
  }

  file { $config_dir:
    ensure  => directory,
    purge   => $purge_config_dir,
    recurse => true,
  }

  # The storage backend needs a real, writable directory owned by the
  # vault user — without this, "vault operator init" fails with
  # "permission denied" trying to create its keyring on first start.
  file { "${config_dir}/data":
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '0750',
    require => [File[$config_dir], User[$user], Group[$group]],
  }

  file { "${config_dir}/config.hcl":
    ensure  => file,
    content => template('vault/config.hcl.erb'),
    require => File[$config_dir],
    notify  => Service[$service_name],
  }

  file { "/etc/systemd/system/${service_name}.service":
    ensure  => file,
    content => template('vault/vault.service.erb'),
    notify  => [Exec['systemd-reload-vault'], Service[$service_name]],
  }

  exec { 'systemd-reload-vault':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  service { $service_name:
    ensure  => running,
    enable  => $service_enable,
    require => [
      File["${install_dir}/vault"],
      File["${config_dir}/data"],
      File["${config_dir}/config.hcl"],
      File["/etc/systemd/system/${service_name}.service"],
    ],
  }
}
