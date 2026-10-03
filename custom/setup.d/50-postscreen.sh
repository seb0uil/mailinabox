#!/bin/bash
# Custom hook (sourced by setup/start.sh after upstream configuration).
#
# Put postscreen in front of smtpd on port 25 and configure its DNSBLs,
# using the Spamhaus Data Query Service (DQS) instead of the public
# zen.spamhaus.org mirror. The DQS key is a secret and is kept out of the
# repository, in $STORAGE_ROOT/custom/spamhaus-dqs.key.

postscreen_changed=

# master.cf: smtp/inet -> postscreen, which hands clients over to smtpd/pass.
if [ "$(postconf -M smtp/inet | awk '{print $8}')" != "postscreen" ] \
	|| [ -z "$(postconf -M smtpd/pass)" ] \
	|| [ -z "$(postconf -M dnsblog/unix)" ] \
	|| [ -z "$(postconf -M tlsproxy/unix)" ]; then
	postconf -Me "smtp/inet=smtp inet n - y - 1 postscreen"
	postconf -Me "smtpd/pass=smtpd pass - - y - - smtpd"
	postconf -Me "dnsblog/unix=dnsblog unix - - y - 0 dnsblog"
	postconf -Me "tlsproxy/unix=tlsproxy unix - - y - 0 tlsproxy"
	postscreen_changed=1
fi

# main.cf: DNSBLs.
dqs_key_file="$STORAGE_ROOT/custom/spamhaus-dqs.key"
if [ ! -f "$dqs_key_file" ]; then
	echo "WARNING: $dqs_key_file not found; postscreen DNSBLs NOT configured."
else
	dqs_key=$(tr -d '[:space:]' < "$dqs_key_file")
	dnsbl_sites="$dqs_key.zen.dq.spamhaus.net=127.0.0.[2..11]*2 bl.spamcop.net=127.0.0.2*1 b.barracudacentral.org=127.0.0.2*1"
	if [ "$(postconf -h postscreen_dnsbl_sites)" != "$dnsbl_sites" ]; then
		postconf -e "postscreen_dnsbl_sites=$dnsbl_sites"
		postscreen_changed=1
	fi
fi

if [ -n "$postscreen_changed" ]; then
	restart_service postfix
fi
