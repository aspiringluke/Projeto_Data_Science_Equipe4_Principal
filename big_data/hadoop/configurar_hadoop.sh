
#!/usr/bin/env bash
set -euo pipefail

HADOOP_HOME="$HOME/hadoop"
CONFIG_DIR="$HADOOP_HOME/etc/hadoop"

if [ ! -x "$HADOOP_HOME/bin/hadoop" ]; then
    echo "Erro: Hadoop não encontrado em $HADOOP_HOME"
    exit 1
fi

mkdir -p "$HOME/hadoop_data/namenode"
mkdir -p "$HOME/hadoop_data/datanode"
mkdir -p "$HOME/hadoop_tmp"

# Configuração do HDFS
cat > "$CONFIG_DIR/core-site.xml" <<EOF
<?xml version="1.0"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>file://$HOME/hadoop_tmp</value>
    </property>
</configuration>
EOF

cat > "$CONFIG_DIR/hdfs-site.xml" <<EOF
<?xml version="1.0"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file://$HOME/hadoop_data/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file://$HOME/hadoop_data/datanode</value>
    </property>
</configuration>
EOF

# Configuração do MapReduce
cat > "$CONFIG_DIR/mapred-site.xml" <<EOF
<?xml version="1.0"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_HOME</value>
    </property>
    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_HOME</value>
    </property>
    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=$HADOOP_HOME</value>
    </property>
</configuration>
EOF

# Configuração do YARN
cat > "$CONFIG_DIR/yarn-site.xml" <<'EOF'
<?xml version="1.0"?>
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.env-whitelist</name>
        <value>JAVA_HOME,HADOOP_HOME,HADOOP_CONF_DIR,HADOOP_MAPRED_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_YARN_HOME,PATH,LANG,TZ</value>
    </property>
</configuration>
EOF

echo "Configurações do Hadoop gravadas com sucesso."
echo "ATENÇÃO: Não formate novamente o NameNode se o HDFS já estiver inicializado."