#!/usr/bin/env bash
set -e

ROLE=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/dataproc-role)
INIT_ACTIONS_REPO=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/INIT_ACTIONS_REPO || true)
INIT_ACTIONS_REPO="${INIT_ACTIONS_REPO:-https://github.com/GoogleCloudPlatform/dataproc-initialization-actions.git}"
INIT_ACTIONS_BRANCH=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/INIT_ACTIONS_BRANCH || true)
INIT_ACTIONS_BRANCH="${INIT_ACTIONS_BRANCH:-master}"
DATAPROC_BUCKET=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/dataproc-bucket)

# Colon-separated list of conda channels to add before installing packages
JUPYTER_CONDA_CHANNELS=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/JUPYTER_CONDA_CHANNELS || true)
# Colon-separated list of conda packages to install, for example 'numpy:pandas'
JUPYTER_CONDA_PACKAGES=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/JUPYTER_CONDA_PACKAGES || true)

echo "Cloning fresh dataproc-initialization-actions from repo $INIT_ACTIONS_REPO and branch $INIT_ACTIONS_BRANCH..."
git clone -b "$INIT_ACTIONS_BRANCH" --single-branch $INIT_ACTIONS_REPO
# Ensure we have conda installed.
./dataproc-initialization-actions/conda/bootstrap-conda.sh

source /etc/profile.d/conda.sh

if [ -n "${JUPYTER_CONDA_CHANNELS}" ]; then
  echo "Adding custom conda channels '$(echo ${JUPYTER_CONDA_CHANNELS} | tr ':' ' ')'"
  conda config --add channels $(echo ${JUPYTER_CONDA_CHANNELS} | tr ':' ',')
fi

if [ -n "${JUPYTER_CONDA_PACKAGES}" ]; then
  echo "Installing custom conda packages '$(echo ${JUPYTER_CONDA_PACKAGES} | tr ':' ' ')'"
  conda install $(echo ${JUPYTER_CONDA_PACKAGES} | tr ':' ' ')
fi

pip install h2o_pysparkling_2.0

if [[ "${ROLE}" == 'Master' ]]; then
    # Sparkling water setup
    SPARKLING_WATER_MAJOR=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/SPARKLING_WATER_MAJOR || true)
    SPARKLING_WATER_MAJOR="${SPARKLING_WATER_MAJOR:-2.0}"

    SPARKLING_WATER_MINOR=$(curl -f -s -H Metadata-Flavor:Google http://metadata/computeMetadata/v1/instance/attributes/SPARKLING_WATER_MINOR || true)
    SPARKLING_WATER_MINOR="${SPARKLING_WATER_MINOR:-9}"

    SPARKLING_WATER_VERSION="${SPARKLING_WATER_MAJOR}.${SPARKLING_WATER_MINOR}"
    SPARKLING_WATER_URL="http://h2o-release.s3.amazonaws.com/sparkling-water/rel-${SPARKLING_WATER_MAJOR}/${SPARKLING_WATER_MINOR}/sparkling-water-${SPARKLING_WATER_VERSION}.zip"
    HADOOP_VERSION=hdp2.6

    echo "Retrieving Sparkling Water (version ${SPARKLING_WATER_VERSION})"
    wget ${SPARKLING_WATER_URL}
    unzip sparkling-water-${SPARKLING_WATER_VERSION}.zip
    echo "Create extended JAR for Hadoop version ${HADOOP_VERSION}"
    ./sparkling-water-${SPARKLING_WATER_VERSION}/bin/get-extended-h2o.sh ${HADOOP_VERSION}

    echo "Make H2O extended JAR available to the environment and Spark"
    echo "H2O_EXTENDED_JAR=`pwd`/h2odriver-${HADOOP_VERSION}-extended.jar" | tee -a /etc/environment /usr/lib/spark/conf/spark-env.sh

    conda install jupyter
    if gsutil -q stat "gs://$DATAPROC_BUCKET/notebooks/**"; then
        echo "Pulling notebooks directory to cluster master node..."
        gsutil -m cp -r gs://$DATAPROC_BUCKET/notebooks /root/
    fi
    ./dataproc-initialization-actions/jupyter/internal/setup-jupyter-kernel.sh
    ./dataproc-initialization-actions/jupyter/internal/launch-jupyter-kernel.sh

fi
echo "Completed installing Jupyter!"

# Install Jupyter extensions (if desired)
# TODO: document this in readme
if [[ ! -v $INSTALL_JUPYTER_EXT ]]
    then
    INSTALL_JUPYTER_EXT=false
fi
if [[ "$INSTALL_JUPYTER_EXT" = true ]]
then
    echo "Installing Jupyter Notebook extensions..."
    ./dataproc-initialization-actions/jupyter/internal/bootstrap-jupyter-ext.sh
    echo "Jupyter Notebook extensions installed!"
fi

