echo "now is `date`"
if [ $# != 3 ]; then
  echo "usage:"
  echo "    ./start.sh {host_ip}"
  exit 1
fi

HOST=$1
CRT_FILE_NAME=$2
KEY_FILE_NAME=$3
echo "listen IP/DomainName is $HOST."

echo "stop running blog..."
sudo docker ps -a | grep blog | awk '{print $1}' | xargs sudo docker rm -f

echo "clean last build."
git reset --hard
git clean -dfx

echo "pull latest code from github"
git pull

echo "rebuilt blog html."
sed -i "s/localhost/$HOST/g" config.yml
sed -i "s/localhost/$HOST/g" nginx/conf.d/80.conf
sed -i "s/localhost/$HOST/g" nginx/conf.d/403.conf
sed -i "s/ssl_demo_crt.crt/$CRT_FILE_NAME/g"
sed -i "s/ssl_demo_key.key/$KEY_FILE_NAME/g"
mkdir -p cache
hugo --cacheDir=`pwd`/cache

echo "rebuilt nginx directory."
mkdir -p nginx/html
mkdir -p nginx/logs

echo "copy generated html resource."

mv public/* nginx/html/

echo "starting blog."
sudo docker run -id --name=yeluo-blog -p 80:80 -v $PWD/nginx/conf/nginx.conf:/etc/nginx/nginx.conf -v $PWD/nginx/conf.d:/etc/nginx/conf.d -v $PWD/nginx/logs:/var/log/nginx -v $PWD/nginx/html:/usr/share/nginx/html -v $PWD/cert:/etc/nginx/cert  nginx
echo "start success."