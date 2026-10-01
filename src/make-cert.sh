sudo openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout /etc/nginx/s1.femtost.com.key \
  -out /etc/nginx/s1.femtost.com.crt \
  -subj "/CN=s1.femtost.com" \
  -addext "subjectAltName=DNS:s1.femtost.com"
  