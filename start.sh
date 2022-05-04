HOST=$1

echo "stop running blog..."
sudo docker stop `docker ps | grep blog | awk '{print $1}'`

echo "clean last build."
git reset --hard
git clean -dfx

echo "rebuilt blog html."
sed -i "s/localhost/$HOST/g" config.yml
sed -i "s/localhost/$HOST/g" nginx/conf.d/80.conf
hugo

echo "rebuilt nginx directory."
mkdir -p nginx/html
mkdir -p nginx/logs

echo "copy generated html resource."

mv public/* nginx/html/

echo "starting blog."
sudo docker run -id --name=yeluo-blog -p 80:80 -v $PWD/nginx/conf/nginx.conf:/etc/nginx/nginx.conf -v $PWD/nginx/conf.d:/etc/nginx/conf.d -v $PWD/nginx/logs:/var/log/nginx -v $PWD/nginx/html:/usr/share/nginx/html nginx
echo "start success."