ssl on;
ssl_session_cache shared:SSL:5m;
ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
ssl_prefer_server_ciphers on;
ssl_dhparam /etc/nginx/dhparam.pem;
ssl_certificate /etc/letsencrypt/live/all/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/all/privkey.pem;
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/all/fullchain.pem;

add_header Expect-CT "enforce, max-age=2592000";
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
