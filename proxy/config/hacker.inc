root /var/www/http;
gzip_static on;
lingering_close off;
try_files /bomb.htm =444;
