# Class: puppet_agent7::upgrade
#
# Declared by puppet_agent7 only on nodes still running Puppet 5, in the last
# run stage. Replaces puppet-agent 5 with 7 (yum upgrade, same package name),
# then restarts the agent daemon so it loads the new code.
class puppet_agent7::upgrade (
  String $version,
) {
  package { 'puppet-agent':
    ensure  => $version,
    require => Yumrepo['puppet7'],
  }
  exec { 'restart-puppet-agent-after-upgrade':
    command     => '/usr/bin/systemctl try-restart puppet',
    refreshonly => true,
    subscribe   => Package['puppet-agent'],
  }
}
