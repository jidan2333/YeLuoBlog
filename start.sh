echo "input args num:$#, args:$1"
if [ $# != 1 ]; then
  echo "usage:"
  echo "    ./start.sh {host_ip}"
  exit 1
fi

HOST=$1
echo "listen IP/DomainName is $HOST."

echo "stop running blog..."
sudo docker ps -a | grep blog | awk '{print $1}' | xargs sudo docker rm -f

echo "clean last build."
git reset --hard
git clean -dfx

echo "rebuilt blog html."
sed -i "s/localhost/$HOST/g" config.yml
sed -i "s/localhost/$HOST/g" nginx/conf.d/80.conf
mkdir -p cache
hugo --cacheDir=`pwd`/cache

echo "rebuilt nginx directory."
mkdir -p nginx/html
mkdir -p nginx/logs

echo "copy generated html resource."

mv public/* nginx/html/

echo "starting blog."
sudo docker run -id --name=yeluo-blog -p 80:80 -v $PWD/nginx/conf/nginx.conf:/etc/nginx/nginx.conf -v $PWD/nginx/conf.d:/etc/nginx/conf.d -v $PWD/nginx/logs:/var/log/nginx -v $PWD/nginx/html:/usr/share/nginx/html nginx
echo "start success."