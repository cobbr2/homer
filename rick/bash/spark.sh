export SPARK_HOME=${HOME}/spark/spark
path_append ${SPARK_HOME}/bin
path_append ${HOME}/spark/hadoop/bin
# Probably time to go with VirtualEnv or asdf
export PYTHONPATH=$(echo $SPARK_HOME/python/lib/py4j-*-src.zip):$SPARK_HOME/python/:$PYTHONPATH
