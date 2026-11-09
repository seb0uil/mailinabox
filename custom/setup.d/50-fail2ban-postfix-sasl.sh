#!/bin/bash
# Custom hook (sourced by setup/start.sh after upstream configuration).
#
# Widen the fail2ban window for SMTP AUTH failures: ban after 3 failures in
# a day, for a day (instead of 5 failures in 10 minutes, for 10 minutes), to
# catch distributed brute force that stays under the default per-IP rate.
# Kept in its own jail.d file, since upstream regenerates mailinabox.conf.

source custom/functions.sh

if install_if_changed custom/files/fail2ban/zz-custom.conf /etc/fail2ban/jail.d/zz-custom.conf 644; then
	restart_service fail2ban
fi
