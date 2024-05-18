#!/usr/bin/env bash
echo "Making tools folder within which I'll put clouseau."
mkdir -p tools
cd tools
echo -n "Checking if clouseau zipfile exists already…"
if [ ! -e "clouseau-2.23.0-dist.zip" ]; then
  echo "no, I'll download it."
  curl -L -O -C - https://github.com/cloudant-labs/clouseau/releases/download/2.23.0/clouseau-2.23.0-dist.zip
else
  echo "yes, it does."
fi
if [ -d "clouseau-2.23.0" ]; then
  echo "clouseau has been installed already. I assume you want to do a fresh install; I'll kill it and re-install it."
  rm -Rf clouseau-2.23.0
fi
unzip clouseau-2.23.0-dist.zip
cd clouseau-2.23.0
echo "Creating clouseau.ini."
if [ -e "/var/lib/couchdb/.erlang.cookie" ]; then
  echo "Hmm, I'm running on NixOS, I think? Let me get the random cookie.  Please authenticate."
  cookie=$(sudo cat /var/lib/couchdb/.erlang.cookie)
else
  cookie="localmonster" # This is the default cookie for Ubuntu, I think
fi
cat <<EOF > clouseau.ini
[clouseau]
name=clouseau@127.0.0.1
cookie=$cookie
dir=$PWD
max_indexes_open=500
EOF
echo "Creating log4j.properties."
cat <<EOF > log4j.properties
log4j.rootLogger=debug, CONSOLE
log4j.appender.CONSOLE=org.apache.log4j.ConsoleAppender
log4j.appender.CONSOLE.layout=org.apache.log4j.PatternLayout
log4j.appender.CONSOLE.layout.ConversionPattern=%d{ISO8601} %c [%p] %m%n"
EOF
echo "Fixing up slf4j dependency."
rm slf4j-api-1.7.32.jar
curl -L -O -C - https://repo1.maven.org/maven2/org/slf4j/slf4j-api/2.0.12/slf4j-api-2.0.12.jar
curl -L -O -C - https://repo1.maven.org/maven2/org/slf4j/slf4j-simple/2.0.12/slf4j-simple-2.0.12.jar
echo "Creating start_clouseau.sh script file."
cat <<EOF > ../../start_clouseau.sh
#!/bin/sh
java -server -Xmx2G -Dsun.net.inetaddr.ttl=30 -Dsun.net.inetaddr.negative.ttl=30 -Dlog4j.configuration=file:$PWD/log4j.properties -XX:OnOutOfMemoryError="kill -9 %p" -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -classpath '$PWD/*' com.cloudant.clouseau.Main $PWD/clouseau.ini
EOF
cd ../../
chmod +x start_clouseau.sh
echo "Done! (I hope.) Run ./start_clouseau.sh to start clouseau."
