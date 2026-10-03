#!/bin/bash
# Custom hook (sourced by setup/start.sh after upstream configuration).
#
# Run the box on IPv4 only: disable IPv6 in the kernel, then make
# Mail-in-a-Box and Postfix stop using it.
#
# Setup detects the IPv6 address (setup/questions.sh) before the hooks run,
# so on the first run the address is already in /etc/mailinabox.conf and in
# the DNS zones: clear it and regenerate them. Later runs detect no IPv6.

source custom/functions.sh

if install_if_changed custom/files/sysctl/99-disable-ipv6.conf /etc/sysctl.d/99-disable-ipv6.conf 644; then
	hide_output sysctl -p /etc/sysctl.d/99-disable-ipv6.conf
fi

if grep -qE '^(PUBLIC|PRIVATE)_IPV6=.+' /etc/mailinabox.conf; then
	echo "Removing the IPv6 address from the Mail-in-a-Box configuration..."
	sed -i 's/^PUBLIC_IPV6=.*/PUBLIC_IPV6=/; s/^PRIVATE_IPV6=.*/PRIVATE_IPV6=/' /etc/mailinabox.conf
	PUBLIC_IPV6=
	PRIVATE_IPV6=

	# The management daemon reads /etc/mailinabox.conf at startup: restart
	# it, then regenerate the DNS zones (without AAAA records) and nginx.
	restart_service mailinabox
	until nc -z -w 4 127.0.0.1 10222; do
		echo "Waiting for the Mail-in-a-Box management daemon to start..."
		sleep 2
	done
	tools/dns_update
	tools/web_update
fi

postfix_changed=
postconf_set inet_protocols=ipv4 smtp_bind_address6=
if [ -n "$postfix_changed" ]; then
	restart_service postfix
fi
