set -euo pipefail

HADOOP_VERSION="3.4.2"
HADOOP_DIR="$HOME/hadoop"

echo "Instalando dependências..."
sudo apt update
sudo apt install -y wget tar openssh-client

echo "Baixando Apache Hadoop ${HADOOP_VERSION}..."
cd "$HOME"
wget -c "https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"

echo "Extraindo Hadoop..."
tar -xzf "hadoop-${HADOOP_VERSION}.tar.gz"

if [ -e "$HADOOP_DIR" ]; then
    echo "A pasta $HADOOP_DIR já existe. Não vou sobrescrevê-la."
    exit 1
fi

mv "hadoop-${HADOOP_VERSION}" "$HADOOP_DIR"

echo "Hadoop instalado em $HADOOP_DIR"
