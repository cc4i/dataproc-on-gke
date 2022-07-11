#!/bin/bash 
set -x 

# Inject environments 
source ./env.sh

# Provision history server
state=`gcloud dataproc clusters describe phs-server4dp-gpm --region us-central1 --format="json"|jq -r ".status.state"`
if [ ${state}="RUNNING" ]
then
  echo "History server is running."
else
  gcloud dataproc clusters create ${PHS_CLUSTER} \
      --region=${REGION} \
      --single-node \
      --enable-component-gateway \
      --properties=spark:spark.history.fs.logDirectory=gs://${DP_BUCKET}/spark-job-history
fi

# Build custome image for DP cluster
cd ..
gcloud artifacts repositories describe jigaree --location us-central1 --format="json"
if [ $? == 1 ]
then 
  echo "Create a artifact repo"
  gcloud artifacts repositories create ${DP_IMAGE_REPO}  \
    --repository-format docker \
    --location=${REGION}
fi

dp_image=${REGION}-docker.pkg.dev/${PROJECT_ID}/DP_IMAGE_REPO/dataproc-test:latest
docker build -t ${dp_image} .
gcloud auth configure-docker ${REGION}-docker.pkg.dev
docker push 
cd -

# Create DP cluster with specific properties
# >1. Custom image with jmx agent and Prometheus configuration files.
# >2. Using JmxSink to collect metrics for Prometheus.
# >3. Attach history server.
gcloud dataproc clusters gke create ${DP_CLUSTER} \
    --region=${REGION} \
    --gke-cluster=${GKE_CLUSTER} \
    --gke-cluster-location=${REGION} \
    --properties="spark:spark.kubernetes.container.image=${dp_image}" \
    --properties="spark:spark.metrics.conf.*.sink.jmx.class=org.apache.spark.metrics.sink.JmxSink" \
    --properties="spark:spark.ui.prometheus.enabled=true" \
    --properties="spark:spark.metrics.conf.master.source.jvm.class=org.apache.spark.metrics.source.JvmSource" \
    --properties="spark:spark.metrics.conf.worker.source.jvm.class=org.apache.spark.metrics.source.JvmSource" \
    --properties="spark:spark.metrics.conf.driver.source.jvm.class=org.apache.spark.metrics.source.JvmSource" \
    --properties="spark:spark.metrics.conf.executor.source.jvm.class=org.apache.spark.metrics.source.JvmSource" \
    --properties="spark:spark.driver.extraJavaOptions=-javaagent:/opt/spark/jars/jmx_prometheus_javaagent-0.17.0.jar=9091:/usr/lib/spark/conf/prometheus-config.yml" \
    --properties="spark:spark.executor.extraJavaOptions=-javaagent:/opt/spark/jars/jmx_prometheus_javaagent-0.17.0.jar=9091:/usr/lib/spark/conf/prometheus-config.yml" \
    --spark-engine-version=latest \
    --staging-bucket=${DP_BUCKET} \
    --pools="name=${DP_POOLNAME},roles=default" \
    --setup-workload-identity \
    --history-server-cluster=${PHS_CLUSTER}


# Apply PodMonitoring to collect driver/executor metrics
kubectl apply -f manifests/podmonitoring.yaml -n ${DP_CLUSTER}

