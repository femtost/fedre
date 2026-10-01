sudo chmod 777 /etc/nginx/conf.d
cp -f proxy.conf /etc/nginx/conf.d/s1.femtost.com.conf
sudo nginx -t
sudo service nginx status
sudo service nginx restart
