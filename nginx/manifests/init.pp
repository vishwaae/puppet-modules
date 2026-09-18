class nginx (
  Integer $worker_processes =   lookup('nginx::worker_processes'),
  Boolean $default_vhost    =   lookup('nginx::default_vhost'),
  String $package_name      =   lookup('nginx::package_name'),
  String $service_name      =   lookup('nginx::service_name'),
  String $ensure            =   lookup('nginx::ensure'),
  Boolean $enable           =   lookup('nginx::enable'),
  String $service_state     =   lookup('nginx::service_state'),
) {
  package { $package_name:
    ensure  =>  $ensure,
  }
#nginx service
  service { $service_name:
    ensure  =>  $service_state,
    enable  =>  $enable,
    require =>  Package[$package_name],
  }

  file  { '/etc/nginx/nginx.conf':
    ensure  =>  file,
    content =>  template('nginx/nginx.conf.erb'),
    notify  =>  Service[$service_name],
  }
}  
