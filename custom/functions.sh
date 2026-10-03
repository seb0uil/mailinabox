#!/bin/bash
# Helpers shared by the custom hooks in custom/setup.d/.

function postconf_set {
	# postconf_set NAME=VALUE [NAME=VALUE ...]
	# Set Postfix main.cf parameters, only when they differ from the current
	# value. Sets postfix_changed=1 when something was modified.
	local setting
	for setting in "$@"; do
		if [ "$(postconf -h "${setting%%=*}")" != "${setting#*=}" ]; then
			postconf -e "$setting"
			postfix_changed=1
		fi
	done
}

function install_if_changed {
	# install_if_changed SOURCE DEST MODE
	# Copy SOURCE to DEST (owned by root) when the content differs.
	# Returns 0 when DEST was (re)written, 1 otherwise.
	if cmp -s "$1" "$2"; then
		return 1
	fi
	install -m "$3" -o root -g root "$1" "$2"
}
