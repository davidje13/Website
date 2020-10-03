ssl_session_cache shared:SSL:5m;
ssl_protocols TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_ciphers HIGH:!aNULL:!MD5:!PSK:!CAMELLIA:!SHA1:!SHA256:!SHA384:!AES128:!ARIA128:!AES256-GCM-SHA384:!AES256-CCM8:!AES256-CCM:!ARIA256-GCM-SHA384;
ssl_dhparam /etc/nginx/dhparam.pem;
ssl_certificate /etc/letsencrypt/live/all/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/all/privkey.pem;
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/all/fullchain.pem;

add_header Expect-CT "enforce, max-age=2592000" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;

# test cipher options with:
# openssl ciphers -tls1 'HIGH:!aNULL:!MD5' | tr ':' '\n'
# see https://www.openssl.org/docs/man1.0.2/man1/ciphers.html
