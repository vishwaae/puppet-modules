# Class: puppet_agent7
#
# Same interface as puppet_agent5, for Puppet 7 agents. Migration = swap
# puppet_agent5 for puppet_agent7 in a role (one role at a time as a canary).
# Rollback = swap back (puppet_agent5 re-enables the puppet5 repo and pins 5.5.22).
class puppet_agent7 (
  String        $server                 = lookup('puppet_agent7::server'),
  Integer       $serverport              = lookup('puppet_agent7::serverport'),
  String        $ca_server              = lookup('puppet_agent7::ca_server'),
  Integer       $ca_port                = lookup('puppet_agent7::ca_port'),
  Boolean       $certificate_revocation = lookup('puppet_agent7::certificate_revocation'),
  String        $agent_version          = lookup('puppet_agent7::agent_version'),
  String        $repo_baseurl           = lookup('puppet_agent7::repo_baseurl'),
  String        $repo_gpgkey            = lookup('puppet_agent7::repo_gpgkey'),
  Array[String] $base_packages          = lookup('puppet_agent7::base_packages'),
) {

  # certname and private_ip are NEVER looked up from data — they're
  # already known live, from this node's own facts, every single run.
  # This is what makes the whole design scale to any number of nodes
  # with zero per-node files: nothing to create, ever, no matter how
  # many nodes join.
  $certname   = $trusted['certname']
  $private_ip = $facts['networking']['ip']

  # The repo/package were necessarily installed via bash before Puppet
  # could run at all (a real, unavoidable bootstrap-order limit) — but
  # from here on, THIS class owns and enforces them. If the pinned
  # version or the repo itself ever drifts (a manual upgrade, someone
  # removing the repo file), the next agent run corrects it back.
  yumrepo { 'puppet7':
    baseurl  => $repo_baseurl,
    descr    => 'Puppet 7 Repository',
    enabled  => 1,
    gpgcheck => 1,
    gpgkey   => $repo_gpgkey,
  }

  # Old repo off, so yum can never pick a Puppet 5 package again.
  yumrepo { 'puppet5':
    enabled => 0,
  }

  # Which Puppet is running this catalog right now (5 before the upgrade, 7 after).
  $installed_major = Integer(split($facts['puppetversion'], '[.]')[0])

  # Upgrade only if Puppet 5 is installed. A node already on 7 (or newer)
  # gets no package action at all. The upgrade runs in a final stage, after
  # every other resource of this run, and yum replaces 5 with 7 in place
  # (same package name): no uninstall, SSL certs/keys untouched.
  if $installed_major == 5 {
    stage { 'puppet_upgrade':
      require => Stage['main'],
    }
    class { 'puppet_agent7::upgrade':
      stage   => 'puppet_upgrade',
      version => $agent_version,
    }
  }

  # Full, final puppet.conf — replaces post_script.sh's minimal bootstrap
  # version with the complete config (dns_alt_names etc.) every run.
  file { '/etc/puppetlabs/puppet/puppet.conf':
    ensure  => file,
    content => template('puppet_agent7/puppet.conf.erb'),
  }

  # No owner/group here — same reasoning as post_script.sh: agent-only
  # nodes have no "puppet" system user at all, since the plain agent
  # runs as root. Setting owner/group here would fail every single
  # catalog run on a worker, not just once.
  file { '/etc/puppetlabs/puppet/ssl':
    ensure => directory,
  }

  # Base OS packages every agent needs, re-asserted every run — moved
  # here from post_script.sh. Names come from Hiera, not hardcoded here,
  # matching the rest of this build's discipline.
  package { $base_packages:
    ensure => present,
  }

  # PATH export — moved here from post_script.sh.
  file_line { 'puppet_path':
    path => '/root/.bashrc',
    line => 'export PATH=/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:$PATH',
  }

  # Custom fact — moved here from post_script.sh. Puppet manages its own
  # classification-support fact from here on.
  file { ['/etc/puppetlabs/facter', '/etc/puppetlabs/facter/facts.d']:
    ensure => directory,
  }
  file { '/etc/puppetlabs/facter/facts.d/intended_hostgroup.sh':
    ensure => file,
    mode   => '0755',
    source => 'puppet:///modules/puppet_agent7/intended_hostgroup.sh',
  }

  # The ongoing agent daemon — periodic runs from here on are Puppet's
  # own job, not a cron entry or repeated manual invocation.
  service { 'puppet':
    ensure  => running,
    enable  => true,
    require => File['/etc/puppetlabs/puppet/puppet.conf'],
  }
}
