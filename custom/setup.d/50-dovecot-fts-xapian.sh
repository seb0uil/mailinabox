#!/bin/bash
# Custom hook (sourced by setup/start.sh after upstream configuration).
#
# Full-text search in Dovecot with the Xapian backend. Indexes are stored in
# each user's mail home, under $STORAGE_ROOT.

source custom/functions.sh

dovecot_conf_before=$(cat /etc/dovecot/conf.d/* | md5sum)

if ! dpkg -s dovecot-fts-xapian > /dev/null 2>&1; then
	apt_install dovecot-fts-xapian
fi

install_if_changed custom/files/dovecot/19-local-fts-xapian.conf \
	/etc/dovecot/conf.d/19-local-fts-xapian.conf 644 || true

# Clean up a former manual setup, which listed the plugins in each protocol
# block and in 90-plugin.conf: they are now inherited from the global setting.
sed -i 's/ fts fts_xapian//' /etc/dovecot/conf.d/20-imap.conf /etc/dovecot/conf.d/20-lmtp.conf
if grep -q fts_xapian /etc/dovecot/conf.d/90-plugin.conf; then
	cat > /etc/dovecot/conf.d/90-plugin.conf << EOF;
##
## Plugin settings
##

# All wanted plugins must be listed in mail_plugins setting before any of the
# settings take effect. See <doc/wiki/Plugins.txt> for list of plugins and
# their configuration. Note that %variable expansion is done for all values.

plugin {
  #setting_name = value
}
EOF
fi

if [ "$dovecot_conf_before" != "$(cat /etc/dovecot/conf.d/* | md5sum)" ]; then
	restart_service dovecot
fi
