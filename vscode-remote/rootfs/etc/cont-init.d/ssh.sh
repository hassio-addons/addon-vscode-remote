#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Community Add-on: VSCode Remote
# Configures the SSH daemon
# ==============================================================================
readonly SSH_AUTHORIZED_KEYS_PATH=/etc/ssh/authorized_keys
readonly SSH_CONFIG_PATH=/etc/ssh/sshd_config
readonly SSH_HOST_ED25519_KEY=/data/ssh_host_ed25519_key
readonly SSH_HOST_RSA_KEY=/data/ssh_host_rsa_key
declare password

# We require at least a password or an authorized key
if bashio::config.is_empty 'authorized_keys' \
    && bashio::config.is_empty 'password';
then
    bashio::log.fatal
    bashio::log.fatal 'Configuration of this add-on is incomplete.'
    bashio::log.fatal
    bashio::log.fatal 'Please be sure to set a least a password'
    bashio::log.fatal 'or at least one authorized key!'
    bashio::log.fatal
    bashio::log.fatal 'You can configure this using the "password"'
    bashio::log.fatal 'or the "authorized_keys" option in the'
    bashio::log.fatal 'add-on configuration.'
    bashio::log.fatal
    bashio::exit.nok
fi

# Require a secure password
if bashio::config.has_value 'password' \
    && ! bashio::config.true 'i_like_to_be_pwned'; then
    bashio::config.require.safe_password 'password'
fi

# Warn about password login
if bashio::config.has_value 'password'; then
    bashio::log.warning
    bashio::log.warning \
        'Logging in with a SSH password is security wise, a bad idea!'
    bashio::log.warning 'Please, consider using a public/private key pair.'
    bashio::log.warning 'What is this? https://kb.iu.edu/d/aews'
    bashio::log.warning
fi

# Generate host keys
if ! bashio::fs.file_exists "${SSH_HOST_RSA_KEY}"; then
    bashio::log.notice 'RSA host key missing, generating one...'

    ssh-keygen -t rsa -f "${SSH_HOST_RSA_KEY}" -N "" \
        || bashio::exit.nok 'Failed to generate RSA host key'
fi

if ! bashio::fs.file_exists "${SSH_HOST_ED25519_KEY}"; then
    bashio::log.notice 'ED25519 host key missing, generating one...'
    ssh-keygen -t ed25519 -f "${SSH_HOST_ED25519_KEY}" -N "" \
        || bashio::exit.nok 'Failed to generate ED25519 host key'
fi

# We need to set a password for the user account
if bashio::config.has_value 'password'; then
    password=$(bashio::config 'password')
else
    # Use a random password in case none is set
    password=$(pwgen 64 1)
fi
chpasswd <<< "root:${password}" 2&> /dev/null

# Sets up the authorized SSH keys
if bashio::config.has_value 'authorized_keys'; then
    while read -r key; do
        echo "${key}" >> "${SSH_AUTHORIZED_KEYS_PATH}"
    done <<< "$(bashio::config 'authorized_keys')"
fi

# Enable password authentication when password is set
if bashio::config.has_value 'ssh.password'; then
    sed -i "s/PasswordAuthentication.*/PasswordAuthentication\\ yes/" \
        "${SSH_CONFIG_PATH}" \
          || bashio::exit.nok 'Failed to setup SSH password authentication'
fi
