
set -euo pipefail

HADOOP_HOME="$HOME/hadoop"

if [ ! -x "$HADOOP_HOME/bin/hdfs" ]; then
    echo "Erro: Hadoop não encontrado."
    exit 1
fi

iniciar_servico() {
    local nome="$1"
    local comando="$2"
    local servico="$3"

    if jps -l | grep -q "org.apache.hadoop.${nome}"; then
        echo "$servico já está em execução."
    else
        echo "Iniciando $servico..."
        "$HADOOP_HOME/bin/$comando" --daemon start "$servico"
    fi
}

iniciar_servico "hdfs.server.namenode.NameNode" "hdfs" "namenode"
iniciar_servico "hdfs.server.datanode.DataNode" "hdfs" "datanode"
iniciar_servico "yarn.server.resourcemanager.ResourceManager" "yarn" "resourcemanager"
iniciar_servico "yarn.server.nodemanager.NodeManager" "yarn" "nodemanager"

echo
echo "Serviços Hadoop:"
jps
