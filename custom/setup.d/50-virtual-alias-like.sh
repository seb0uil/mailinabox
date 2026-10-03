#!/bin/bash
# Custom hook (sourced by setup/start.sh after upstream configuration).
#
# Match alias sources with SQL LIKE so that aliases can use wildcards
# (% and _) in their source address. Upstream setup/mail-users.sh writes
# an exact match (source='%s'); rewrite it after the fact.

alias_maps=/etc/postfix/virtual-alias-maps.cf

if grep -q "FROM aliases WHERE '%s' like source" "$alias_maps"; then
	: # already applied
elif grep -q "FROM aliases WHERE source='%s'" "$alias_maps"; then
	sed -i "s/FROM aliases WHERE source='%s'/FROM aliases WHERE '%s' like source/" "$alias_maps"
	restart_service postfix
else
	echo "WARNING: $alias_maps does not contain the expected aliases query;"
	echo "         LIKE alias matching was NOT applied. Check upstream changes."
fi
