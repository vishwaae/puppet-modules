# Class: puppet_master7::upgrade
#
# Declared by puppet_master7 only when manage_packages is true and the node
# still runs Puppet 5, in the last run stage. yum replaces the Puppet 5
# packages with Puppet 7 in place; puppetserver is restarted at the end.
class puppet_master7::upgrade (
  Enum['master', 'ca'] $type,
  String $repo_baseurl,
  String $repo_gpgkey,
  String $agent_version,
  String $puppetserver_version,
  String $termini_version,
  String $r10k_version,
) {
  yumrepo { 'puppet7':
    baseurl  => $repo_baseurl,
    descr    => 'Puppet 7 Repository',
    enabled  => 1,
    gpgcheck => 1,
    gpgkey   => $repo_gpgkey,
  }
  yumrepo { 'puppet5':
    enabled => 0,
  }
  package { 'puppet-agent':
    ensure  => $agent_version,
    require => Yumrepo['puppet7', 'puppet5'],
  }
  package { 'puppetserver':
    ensure  => $puppetserver_version,
    require => Package['puppet-agent'],
  }
  if $type == 'master' {
    package { 'puppetdb-termini':
      ensure  => $termini_version,
      require => Package['puppetserver'],
    }
    # r10k lives in the agent's Ruby; Puppet 7 brings a new Ruby.
    package { 'r10k':
      ensure   => $r10k_version,
      provider => 'puppet_gem',
      require  => Package['puppet-agent'],
    }
    $restart_after = [Package['puppetserver'], Package['puppetdb-termini']]
  } else {
    $restart_after = [Package['puppetserver']]
  }
  exec { 'restart-puppetserver-after-upgrade':
    command     => '/usr/bin/systemctl restart puppetserver',
    refreshonly => true,
    subscribe   => $restart_after,
    timeout     => 600,
  }
}
