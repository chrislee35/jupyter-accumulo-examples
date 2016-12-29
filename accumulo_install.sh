#!/usr/bin/env bash

# install Accumulo, Jupyter, pyaccumulo
# install documentation (or at least bookmarks)
# https://www.digitalocean.com/community/tutorials/how-to-install-the-big-data-friendly-apache-accumulo-nosql-database-on-ubuntu-14-04
# step 0: prepare directories, apt-get, and ssh
cd ~
mkdir download
mkdir install
mkdir jupyter

# step 0.b: apt-get
sudo apt-get install aptitude
sudo aptitude update
sudo aptitude install -y openjdk-8-jdk build-essential git

JAVA_HOME=/usr/lib/jvm/java-8-openjdk-*
JAVA_HOME=`eval echo "${JAVA_HOME}"`

# step 0.c fix the /dev/random pathing issue
#sudo sed -i 's/\/dev\/random/\/dev\/.\/random/' "$JAVA_HOME/jre/lib/security/java.security"

# create an ssh keypair if needed
if [ ! -e "~/.ssh/id_rsa" ]; then
	ssh-keygen -P '' -f "~/.ssh/id_rsa"
fi

# add the pubkey to the authorized_keys list
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# ensure proper permissions on the .ssh directory and authorized_keys file
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

echo "Please accept ssh key if it asks"
ssh localhost exit
ssh 0.0.0.0 exit

# up the file limits for accumulo
echo "$USER	nofile	soft	32768" | sudo tee -a /etc/security/limits.conf
sudo sysctl vm.swappiness=10

# step 1: Download hadoop, zookeeper, accumulo, jupyter, and pyaccumulo
cd ~/download

APACHE_PREFERRED_MIRROR=`curl --silent "https://www.apache.org/dyn/closer.cgi?as_json=1" | fgrep '"preferred": ' | cut -f4 -d\"`

# 1.a download hadoop
HADOOP_BASEURL="$APACHE_PREFERRED_MIRROR/hadoop/common/stable/"
HADOOP_VERSION=`curl --silent "$HADOOP_BASEURL" | grep -o 'href="hadoop-[0-9]*\.[0-9]*\.[0-9]*\.tar.gz"' | cut -f2 -d\"`
wget "$HADOOP_BASEURL/$HADOOP_VERSION"
tar xfz "$HADOOP_VERSION" -C ~/install
HADOOP_VERSION=`basename "$HADOOP_VERSION" .tar.gz`

# 1.b download zookeeper
ZOOKEEPER_BASEURL="$APACHE_PREFERRED_MIRROR/zookeeper/stable/"
ZOOKEEPER_VERSION=`curl --silent "$ZOOKEEPER_BASEURL" | grep -o 'href="zookeeper-[0-9]*\.[0-9]*\.[0-9]*\.tar.gz"' | cut -f2 -d\"`
wget "$ZOOKEEPER_BASEURL/$ZOOKEEPER_VERSION"
tar xfz "$ZOOKEEPER_VERSION" -C ~/install
ZOOKEEPER_VERSION=`basename "$ZOOKEEPER_VERSION" .tar.gz`

# 1.c download accumulo
ACCUMULO_BASEURL="$APACHE_PREFERRED_MIRROR/accumulo/"
ACCUMULO_VERSION=`curl --silent "$ACCUMULO_BASEURL" | grep -o 'href="[0-9]*\.[0-9]*\.[0-9]*/"' | cut -f2 -d\" | sort | tail -1 | sed 's/\///'`
wget "$ACCUMULO_BASEURL/$ACCUMULO_VERSION/accumulo-$ACCUMULO_VERSION-bin.tar.gz"
tar xfz "accumulo-$ACCUMULO_VERSION-bin.tar.gz" -C ~/install

# 1.d update the .bashrc with the paths from the installation thus far
export JAVA_HOME="$JAVA_HOME"
export HADOOP_HOME="/home/ubuntu/install/$HADOOP_VERSION"
export HADOOP_PREFIX="/home/ubuntu/install/$HADOOP_VERSION"
export ZOOKEEPER_HOME="/home/ubuntu/install/$ZOOKEEPER_VERSION"
export ACCUMULO_HOME="/home/ubuntu/install/accumulo-$ACCUMULO_VERSION"
export LD_LIBRARY_PATH="/home/ubuntu/install/$HADOOP_VERSION/lib/native:/home/ubuntu/install/accumulo-$ACCUMULO_VERSION/lib/native"

cat << EOD >> ~/.bashrc
export JAVA_HOME="$JAVA_HOME"
export HADOOP_HOME="$HADOOP_HOME"
export HADOOP_PREFIX="$HADOOP_PREFIX"
export ZOOKEEPER_HOME="$ZOOKEEPER_HOME"
export ACCUMULO_HOME="$ACCUMULO_HOME"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
EOD

source ~/.bashrc

# 1.d download jupyter
sudo apt-get install -y python-pip python-dev
sudo pip install --upgrade pip
sudo pip install jupyter
sudo apt-get install -y python3-pip python3-dev
#sudo pip3 install --upgrade pip
#sudo pip3 install jupyter

# 1.e install pyaccumulo
sudo pip install pyaccumulo
#sudo pip3 install pyaccumulo # 1.5.0.8 doesn't work in Python3

step 2: install hadoop
cd ~/install/"$HADOOP_VERSION"
sed -i.bak "s/#export JAVA_HOME/export JAVA_HOME/;s/export JAVA_HOME=.*/export JAVA_HOME='${JAVA_HOME//\//\\\/}'/" etc/hadoop/hadoop-env.sh
sed -i 's/export ACCUMULO_TSERVER_OPTS=".*"/export ACCUMULO_TSERVER_OPTS="${POLICY} -Xmx128m -Xms128m"/' etc/hadoop/hadoop-env.sh
sed -i 's/.*export HADOOP_OPTS=/export HADOOP_OPTS="$HADOOP_OPTS -XX:-PrintWarnings -Djava.net.preferIPv4Stack=true"/' etc/hadoop/hadoop-env.sh

cat << EOD > etc/hadoop/core-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
EOD

cat << EOD > etc/hadoop/hdfs-site.xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.name.dir</name>
        <value>hdfs_storage/name</value>
    </property>
    <property>
        <name>dfs.data.dir</name>
        <value>hdfs_storage/data</value>
    </property>
    <property>
        <name>dfs.datanode.synconclose</name>
        <value>true</value>
    </property>
</configuration>
EOD

cat << EOD > etc/hadoop/mapred-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
     <property>
         <name>mapred.job.tracker</name>
         <value>localhost:9001</value>
     </property>
</configuration>
EOD

bin/hdfs namenode -format
sbin/start-dfs.sh
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

# step 3. install zookeeper
cd ~/install/$ZOOKEEPER_VERSION
cp conf/zoo_sample.cfg conf/zoo.cfg
bin/zkServer.sh start

# step 4. install accumulo
cd ~/install/accumulo-$ACCUMULO_VERSION
bin/bootstrap_config.sh -s 512MB -n -v 2
sed -i.bak 's/# export ACCUMULO_MONITOR_BIND_ALL/export ACCUMULO_MONITOR_BIND_ALL/' conf/accumulo-env.sh
sed -i 's/ACCUMULO_TSERVER_OPTS="${POLICY} -Xmx48m -Xms48m "/ACCUMULO_TSERVER_OPTS="${POLICY} -Xmx128m -Xms128m "/' conf/accumulo-env.sh
bin/build_native_library.sh

# step 4.b. accumulo-site.xml
echo -n "Accumulo Instance Password (used for servers to communicate with each other): "
read ACCUMULO_INSTANCE_PASSWORD
sed -i.bak "s/>DEFAULT</>$ACCUMULO_INSTANCE_PASSWORD</" conf/accumulo-site.xml
echo -n "Accumulo trace.token.property.password: "
read ACCUMULO_TRACE_TOKEN_PASSWORD
sed -i "s/>secret</>$ACCUMULO_TRACE_TOKEN_PASSWORD</" conf/accumulo-site.xml
sed -i "s/<\/configuration>/  <property>\n    <name>instance.volumes<\/name>\n    <value>hdfs:\/\/localhost:9000\/accumulo<\/value>\n  <\/property>\n<\/configuration>/" conf/accumulo-site.xml

# step 4.c. init accumulo
bin/accumulo init
echo -n "Please tell me the name of the instance again (for the install script to configure the Thrift proxy): "
read ACCUMULO_INSTANCE_NAME

# step 4.d start accumulo
bin/start-all.sh

# step 4.e configure and start proxy
cat << EOD > proxy/proxy.properties
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

useMockInstance=false
useMiniAccumulo=false
protocolFactory=org.apache.thrift.protocol.TCompactProtocol\$Factory
tokenClass=org.apache.accumulo.core.client.security.tokens.PasswordToken
port=42424
maxFrameSize=16M

instance=$ACCUMULO_INSTANCE_NAME
zookeepers=localhost:2181
EOD

bin/accumulo proxy -p proxy/proxy.properties &
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

# step 5. download examples
cd ~/jupyter
git clone https://github.com/chrislee35/jupyter-accumulo-examples.git .
mkdir settings
cat << EOD > settings/__init__.py
HOST="localhost"
PORT=42424
USER="root"
PASS="$ACCUMULO_TRACE_TOKEN_PASSWORD"
EOD
jupyter notebook --ip=0.0.0.0 --notebook-dir=`pwd`
