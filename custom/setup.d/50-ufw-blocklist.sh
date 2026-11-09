#!/bin/bash
# Custom hook (sourced by setup/start.sh after upstream configuration).
#
# Deny all inbound traffic from the networks listed in
# custom/files/ufw/blocklist.txt. The deny rules are inserted at the top of
# the ufw rule list: rules are matched in order, so appending them after
# upstream's "allow 25/587/993/..." rules would have no effect.
# The rules carry the comment "custom-blocklist"; those whose network is no
# longer in the list are deleted.

if [ -z "${DISABLE_FIREWALL:-}" ]; then
	ufw_blocklist_comment=custom-blocklist
	ufw_blocklist=$(sed 's/#.*//' custom/files/ufw/blocklist.txt | awk 'NF {print $1}')

	# Networks currently blocked by this hook, as shown by "ufw status":
	# "Anywhere   DENY   92.118.39.0/24   # custom-blocklist".
	ufw_blocked=$(ufw status | awk -v c="# $ufw_blocklist_comment" \
		'$2 == "DENY" && index($0, c) {print $3}')

	for cidr in $ufw_blocklist; do
		if ! grep -qxF "$cidr" <<< "$ufw_blocked"; then
			echo "Blocking $cidr at the firewall..."
			hide_output ufw insert 1 deny from "$cidr" comment "$ufw_blocklist_comment"
		fi
	done

	for cidr in $ufw_blocked; do
		if ! grep -qxF "$cidr" <<< "$ufw_blocklist"; then
			echo "Unblocking $cidr at the firewall..."
			hide_output ufw delete deny from "$cidr"
		fi
	done
fi
