# Use recent protocols and cyphers (disable insecure cyphers)
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers HIGH:!aNULL:!MD5:!PSK:!CAMELLIA:!SHA1:!SHA256:!SHA384:!AES128:!ARIA128:!AES256-GCM-SHA384:!AES256-CCM8:!AES256-CCM:!ARIA256-GCM-SHA384;
ssl_dhparam /etc/nginx/dhparam.pem;

# Reduce server load by using shared cache
ssl_session_cache shared:SSL:5m;

include /etc/nginx/sites-available/ssl-keys.inc;

# HSTS Preloading
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# test cipher options with:
# openssl ciphers -tls1 'HIGH:!aNULL:!MD5' | tr ':' '\n'
# see https://www.openssl.org/docs/man1.0.2/man1/ciphers.html
