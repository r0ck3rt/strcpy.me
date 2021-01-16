#！/bin/bash

# docker run -it -p 127.0.0.1:5000:5000 -v $PWD:/src --workdir /src jekyll/jekyll:3.6.2 ./build.sh
set -ex

rm -rf docs
jekyll build
mv _site docs

echo "pages.strcpy.me" > docs/CNAME