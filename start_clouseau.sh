#!/bin/sh
PWD=`pwd`
java -server -Xmx2G -Dsun.net.inetaddr.ttl=30 -Dsun.net.inetaddr.negative.ttl=30 -Dlog4j.configuration=file:$PWD/tools/clouseau-2.23.0/log4j.properties -XX:OnOutOfMemoryError="kill -9 %p" -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -classpath $PWD'/tools/clouseau-2.23.0/*' com.cloudant.clouseau.Main $PWD/tools/clouseau-2.23.0/clouseau.ini
