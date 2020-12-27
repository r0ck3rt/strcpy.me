#！/bin/bash

# docker run -it -v $PWD:/src --workdir /src jekyll/jekyll:3.6.2 ./build.sh
set -ex

rm -rf docs
jekyll build
mv _site docs

echo "pages.strcpy.me" > docs/CNAME