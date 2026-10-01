# Class: puppet_master7
#
# Manages the Puppet server side of the lab: compile masters and CA nodes.
# - node_type comes from the host name by rule (puppetca* = ca, everything
#   else = master), or from Hiera if set. No per-node files.
# - puppet.conf is always rendered for the Puppet version that is INSTALLED
#   right now (from the puppetversion fact), so the file never gets settings
#   the running version does not understand.
# - Packages are only touched when manage_packages is true. With it false the
#   class just enforces today's config (safe "validate" mode).
class puppet_master7 (
  Optional[Enum['master', 'ca']] $node_type      = undef,
  Boolean $manage_packages                       = false,
  String  $server                                = 'puppetmaster.puppetlab.com',
  Integer $serverport                            = 8142,
  String  $ca_server                             = 'puppetca.puppetlab.com',
  Integer $ca_port                               = 8141,
  String  $repo_baseurl                          = 'https://yum.puppet.com/puppet7/el/7/$basearch',
  String  $repo_gpgkey                           = 'https://yum.puppet.com/RPM-GPG-KEY-puppet-20250406',
  String  $agent_version                         = 'present',
  String  $puppetserver_version                  = 'present',
  String  $termini_version                       = 'present',
  String  $r10k_version                          = 'present',
) {
  $short = $facts['networking']['hostname']
  $type  = $node_type ? {
    undef   => $short ? { /^puppetca/ => 'ca', default => 'master' },
    default => $node_type,
  }

  # Safety: refuse to apply server config to a node whose name does not fit.
  if $type == 'master' and $short !~ /^puppetmaster/ {
    fail("puppet_master7: ${short} is not a puppetmaster* node; refusing to apply master config")
  }
  if $type == 'ca' and $short !~ /^puppetca/ {
    fail("puppet_master7: ${short} is not a puppetca* node; refusing to apply CA config")
  }

  $certname        = $trusted['certname']
  $ip              = $facts['networking']['ip']
  $installed_major = Integer(split($facts['puppetversion'], '[.]')[0])

  # ---------- upgrade (only when asked AND Puppet 5 is installed) ----------
  # Runs in a final stage, after the config resources of this run.
  if $manage_packages and $installed_major == 5 {
    stage { 'puppet_upgrade':
      require => Stage['main'],
    }
    class { 'puppet_master7::upgrade':
      stage                => 'puppet_upgrade',
      type                 => $type,
      repo_baseurl         => $repo_baseurl,
      repo_gpgkey          => $repo_gpgkey,
      agent_version        => $agent_version,
      puppetserver_version => $puppetserver_version,
      termini_version      => $termini_version,
      r10k_version         => $r10k_version,
    }
  }

  # ---------- config ----------
  file { '/etc/puppetlabs/puppet/puppet.conf':
    ensure  => file,
    content => template("puppet_master7/puppet.conf.${type}.erb"),
  }

  if $type == 'master' {
    # Keep the local CA switched off on masters (a package upgrade must not re-enable it).
    file { '/etc/puppetlabs/puppetserver/services.d/ca.cfg':
      ensure => file,
      source => 'puppet:///modules/puppet_master7/ca.cfg.disabled',
      notify => Service['puppetserver'],
    }
  }

  service { 'puppetserver':
    ensure => running,
    enable => true,
  }
}
