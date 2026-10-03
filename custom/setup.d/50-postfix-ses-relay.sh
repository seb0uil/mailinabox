#!/bin/bash
# Custom hook (sourced by setup/start.sh after upstream configuration).
#
# Relay outgoing mail through Amazon SES. The credentials are a secret and
# are kept out of the repository, in $STORAGE_ROOT/custom/sasl_passwd, in
# the Postfix sasl_passwd format; the relay host is taken from its first entry:
#
#   [email-smtp.eu-west-3.amazonaws.com]:587 SMTP_USERNAME:SMTP_PASSWORD

source custom/functions.sh

postfix_changed=
sasl_passwd_src="$STORAGE_ROOT/custom/sasl_passwd"

if [ ! -f "$sasl_passwd_src" ]; then
	echo "WARNING: $sasl_passwd_src not found; SES relay NOT configured."
else
	if install_if_changed "$sasl_passwd_src" /etc/postfix/sasl_passwd 600 \
		|| [ ! -f /etc/postfix/sasl_passwd.db ]; then
		postmap /etc/postfix/sasl_passwd
		chmod 600 /etc/postfix/sasl_passwd.db
		postfix_changed=1
	fi

	# Never send the credentials in clear: plaintext mechanisms (SES only
	# offers PLAIN/LOGIN) are allowed only over TLS.
	postconf_set \
		"relayhost=$(awk '!/^#/ && NF {print $1; exit}' "$sasl_passwd_src")" \
		smtp_sasl_auth_enable=yes \
		smtp_sasl_password_maps=hash:/etc/postfix/sasl_passwd \
		"smtp_sasl_security_options=noanonymous, noplaintext" \
		smtp_sasl_tls_security_options=noanonymous
fi

if [ -n "$postfix_changed" ]; then
	restart_service postfix
fi
