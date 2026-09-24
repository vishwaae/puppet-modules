# The real, actual list of classes for this role lives HERE — in git,
# code-reviewed, versioned — never in Foreman, never in node.rb.
# Adding a class to this role is a one-line edit in this file.
class role::webserver {
  include profile::base
  include puppet_agent5
  include nginx
}
