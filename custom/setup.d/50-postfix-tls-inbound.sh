#!/bin/bash
# Custom hook (sourced by setup/start.sh after upstream configuration).
#
# Harden inbound TLS on port 25. Upstream uses Mozilla's "Old" profile there
# so that very outdated servers can still encrypt; use the "Intermediate"
# profile that upstream already applies to ports 465/587 instead:
#  * TLS 1.2 and 1.3 only;
#  * the "high" cipher list (ECDHE/DHE with AES-GCM or ChaCha20);
#  * no finite-field DHE (self-generated 2048-bit group), ECDHE only.
# Outbound TLS (smtp_*, tls_medium_cipherlist) is left untouched.

source custom/functions.sh

postfix_changed=
postconf_set \
	"smtpd_tls_protocols=!SSLv2,!SSLv3,!TLSv1,!TLSv1.1" \
	smtpd_tls_ciphers=high \
	smtpd_tls_exclude_ciphers=aNULL,RC4,kDHE
if [ -n "$postfix_changed" ]; then
	restart_service postfix
fi
