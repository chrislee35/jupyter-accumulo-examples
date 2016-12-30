#!/usr/bin/env bash
source ~/.bashrc
$HADOOP_HOME/sbin/start-dfs.sh

HDFS_RUNNING=0
for i in `seq 1 60`; do
	curl --silent http://localhost:50070 > /dev/null
	if [ "$?" == "0" ]; then
		HDFS_RUNNING=1
		break
	fi
	sleep 1
done
if [ "$HDFS_RUNNING" == "1" ]; then
	echo "Hadoop looks healthy"
else
	echo "Hadoop didn't start within the allotted time (60 seconds).  Please investigate."
fi
unset HDFS_RUNNING

$ZOOKEEPER_HOME/bin/zkServer.sh start
$ACCUMULO_HOME/bin/start-all.

ACCUMULO_THRIFT_RUNNING=0
for i in `seq 1 15`; do
	PORT_MATCH=`netstat -lnt | fgrep :42424`
	if [ -n "$PORT_MATCH" ]; then
		ACCUMULO_THRIFT_RUNNING=1
		break
	fi
	sleep 1
done
if [ "$ACCUMULO_THRIFT_RUNNING" == "1" ]; then
	echo "Accumulo thrift proxy looks healthy"
else
	echo "Accumulo thrift proxy didn't start within the allotted time (15 seconds).  Please investigate."
fi
unset ACCUMULO_THRIFT_RUNNING
unset PORT_MATCH

jupyter notebook --ip=0.0.0.0 --notebook-dir=$HOME/jupyter &
