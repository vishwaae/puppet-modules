#!/bin/bash
HOSTNAME=$(hostname -s)
case "$HOSTNAME" in
  puppetmaster*) echo "intended_hostgroup=masters" ;;
  puppetca*)     echo "intended_hostgroup=ca" ;;
  worker1)       echo "intended_hostgroup=webserver" ;;
  worker2)       echo "intended_hostgroup=vault" ;;
  worker3)       echo "intended_hostgroup=nginx" ;;
  admin)         echo "intended_hostgroup=admin" ;;
  *)             echo "intended_hostgroup=unknown" ;;
esac
