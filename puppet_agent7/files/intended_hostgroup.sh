#!/bin/bash
# Custom fact: the node's hostgroup, read from its own EC2 tag (set by Terraform).
TOK=$(curl -s -m 2 -X PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
HG=$(curl -sf -m 2 -H "X-aws-ec2-metadata-token: $TOK" http://169.254.169.254/latest/meta-data/tags/instance/Hostgroup)
[ -n "$HG" ] && echo "intended_hostgroup=$HG"
exit 0
