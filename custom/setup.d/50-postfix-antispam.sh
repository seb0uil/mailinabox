#!/bin/bash
# Custom hook (sourced by setup/start.sh after upstream configuration).
#
# Inbound anti-spam on port 25, replacing upstream's greylisting and public
# Spamhaus mirrors:
#  * postscreen in front of smtpd, with DNSBLs queried through the Spamhaus
#    Data Query Service (DQS) and a whitelist of known senders (ESPs);
#  * the DBL sender check moved to DQS;
#  * greylisting (postgrey) no longer consulted. The postgrey service keeps
#    running because the status checks expect it on port 10023.
# The DQS key is a secret and is kept out of the repository, in
# $STORAGE_ROOT/custom/spamhaus-dqs.key.

source custom/functions.sh

postfix_changed=

# master.cf: smtp/inet -> postscreen, which hands clients over to smtpd/pass.
if [ "$(postconf -M smtp/inet | awk '{print $8}')" != "postscreen" ] \
	|| [ -z "$(postconf -M smtpd/pass)" ] \
	|| [ -z "$(postconf -M dnsblog/unix)" ] \
	|| [ -z "$(postconf -M tlsproxy/unix)" ]; then
	postconf -Me "smtp/inet=smtp inet n - y - 1 postscreen"
	postconf -Me "smtpd/pass=smtpd pass - - y - - smtpd"
	postconf -Me "dnsblog/unix=dnsblog unix - - y - 0 dnsblog"
	postconf -Me "tlsproxy/unix=tlsproxy unix - - y - 0 tlsproxy"
	postfix_changed=1
fi

# postscreen: whitelist, pregreet test and DNSBL scoring.
if install_if_changed custom/files/postfix/postscreen_access.cidr /etc/postfix/postscreen_access.cidr 644; then
	postfix_changed=1
fi
postconf_set \
	"postscreen_access_list=permit_mynetworks, cidr:/etc/postfix/postscreen_access.cidr" \
	postscreen_greet_action=enforce \
	postscreen_dnsbl_action=enforce \
	postscreen_dnsbl_threshold=3

# smtpd: drop greylisting (postgrey on port 10023), keep everything else
# from upstream, including the quota policy service.
recipient_restrictions=$(postconf -h smtpd_recipient_restrictions \
	| sed -E 's/,?check_policy_service inet:127\.0\.0\.1:10023//')
postconf_set "smtpd_recipient_restrictions=$recipient_restrictions"

# Spamhaus through DQS: ZEN in postscreen (replacing upstream's public
# reject_rbl_client zen.spamhaus.org) and DBL for the sender domain.
dqs_key_file="$STORAGE_ROOT/custom/spamhaus-dqs.key"
if [ ! -f "$dqs_key_file" ]; then
	echo "WARNING: $dqs_key_file not found; Spamhaus DQS NOT configured."
else
	dqs_key=$(tr -d '[:space:]' < "$dqs_key_file")

	recipient_restrictions=$(postconf -h smtpd_recipient_restrictions \
		| sed -E 's/,?reject_rbl_client zen\.spamhaus\.org[^,]*//')
	sender_restrictions=$(postconf -h smtpd_sender_restrictions \
		| sed "s/reject_rhsbl_sender dbl\.spamhaus\.org/reject_rhsbl_sender $dqs_key.dbl.dq.spamhaus.net/")
	postconf_set \
		"postscreen_dnsbl_sites=$dqs_key.zen.dq.spamhaus.net=127.0.0.[2..11]*3 bl.spamcop.net=127.0.0.2*1 b.barracudacentral.org=127.0.0.2*1" \
		"smtpd_recipient_restrictions=$recipient_restrictions" \
		"smtpd_sender_restrictions=$sender_restrictions"

	if [[ $sender_restrictions != *"$dqs_key.dbl.dq.spamhaus.net"* ]]; then
		echo "WARNING: no DBL check found in smtpd_sender_restrictions;"
		echo "         Spamhaus DBL NOT configured. Check upstream changes."
	fi
fi

if [ -n "$postfix_changed" ]; then
	restart_service postfix
fi
