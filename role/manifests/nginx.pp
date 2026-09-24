class role::nginx {
  include profile::base
  include puppet_agent5
  include nginx
}
