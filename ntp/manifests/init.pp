class ntp (
  String        $package_name = lookup('ntp::package_name'),
  String        $service_name = lookup('ntp::service_name'),
  Boolean       $enable       = lookup('ntp::enable'),
  Array[String] $servers      = lookup('ntp::servers'),
) {

  package { $package_name:
    ensure => present,
  }

  file { '/etc/ntp.conf':
    ensure  => file,
    content => template('ntp/ntp.conf.erb'),
    require => Package[$package_name],
    notify  => Service[$service_name],
  }

  service { $service_name:
    ensure  => running,
    enable  => $enable,
    require => Package[$package_name],
  }
}
