#!/bin/bash
# Run the local customization hooks. Hooks are sourced in lexical order from:
#  * custom/setup.d/ in this repository (versioned customizations),
#  * $STORAGE_ROOT/custom/setup.d/ (machine-local, kept with user data).
#
# Sourced by setup/start.sh at the end of setup. Can also be run on its own,
# as root, to re-apply the customizations without a full setup:
#
#   tools/run_custom_hooks.sh

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
	# Run standalone: provide the environment that setup/start.sh sets up.
	if [[ $EUID -ne 0 ]]; then
		echo "This script must be run as root."
		exit 1
	fi
	cd "$(dirname "$0")/.." || exit 1
	source setup/functions.sh
	source /etc/mailinabox.conf
fi

for hook_dir in custom/setup.d "$STORAGE_ROOT/custom/setup.d"; do
	for hook in "$hook_dir"/*.sh; do
		[ -f "$hook" ] || continue
		echo "Running custom hook $hook..."
		source "$hook"
	done
done
