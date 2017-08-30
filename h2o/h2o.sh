#!/usr/bin/env bash
set -e

ROLE=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/dataproc-role)

INIT_ACTIONS_REPO=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/INIT_ACTIONS_REPO || true)
INIT_ACTIONS_REPO="${INIT_ACTIONS_REPO:-https://github.com/GoogleCloudPlatform/dataproc-initialization-actions.git}"
INIT_ACTIONS_BRANCH=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/INIT_ACTIONS_BRANCH || true)
INIT_ACTIONS_BRANCH="${INIT_ACTIONS_BRANCH:-master}"

if [ ! -d "/dataproc-initialization-actions" ]; then
    echo "Cloning fresh dataproc-initialization-actions from repo $INIT_ACTIONS_REPO and branch $INIT_ACTIONS_BRANCH..."
    git clone -b "$INIT_ACTIONS_BRANCH" --single-branch $INIT_ACTIONS_REPO
fi

# Ensure we have conda installed.
./dataproc-initialization-actions/conda/bootstrap-conda.sh

source /etc/profile.d/conda.sh

# Sparkling water setup
SPARKLING_WATER_MAJOR=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/SPARKLING_WATER_MAJOR || true)
SPARKLING_WATER_MAJOR="${SPARKLING_WATER_MAJOR:-2.0}"

SPARKLING_WATER_MINOR=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/SPARKLING_WATER_MINOR || true)
SPARKLING_WATER_MINOR="${SPARKLING_WATER_MINOR:-15}"

SPARKLING_WATER_VERSION="${SPARKLING_WATER_MAJOR}.${SPARKLING_WATER_MINOR}"

pip install h2o_pysparkling_2.0==${SPARKLING_WATER_VERSION}

if [[ "${ROLE}" == 'Master' ]]; then
    SPARKLING_WATER_URL="http://h2o-release.s3.amazonaws.com/sparkling-water/rel-${SPARKLING_WATER_MAJOR}/${SPARKLING_WATER_MINOR}/sparkling-water-${SPARKLING_WATER_VERSION}.zip"
    HADOOP_VERSION=hdp2.6

    echo "Retrieving Sparkling Water (version ${SPARKLING_WATER_VERSION})"
    wget ${SPARKLING_WATER_URL}
    unzip sparkling-water-${SPARKLING_WATER_VERSION}.zip
    echo "Create extended JAR for Hadoop version ${HADOOP_VERSION}"
    ./sparkling-water-${SPARKLING_WATER_VERSION}/bin/get-extended-h2o.sh ${HADOOP_VERSION}

    echo "Make H2O extended JAR available to the environment and Spark"
    echo "H2O_EXTENDED_JAR=`pwd`/h2odriver-${HADOOP_VERSION}-extended.jar" | tee -a /etc/environment /usr/lib/spark/conf/spark-env.sh

fi
echo "Completed installing H2O and Sparkling water!"
