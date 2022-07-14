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
    --properties="spark:spark.kubernetes.driver.annotation.prometheus.io/scrape=true" \
    --properties="spark:spark.kubernetes.driver.annotation.prometheus.io/path=/metrics/executors/prometheus/" \
    --properties="spark:spark.kubernetes.driver.annotation.prometheus.io/port=4040" \
    --properties="spark:spark.kubernetes.driver.service.annotation.prometheus.io/scrape=true" \
    --properties="spark:spark.kubernetes.driver.service.annotation.prometheus.io/path=/metrics/prometheus/" \
    --properties="spark:spark.kubernetes.driver.service.annotation.prometheus.io/port=4040" \
    --properties="spark:spark.metrics.conf.*.sink.prometheusServlet.class=org.apache.spark.metrics.sink.PrometheusServlet" \
    --properties="spark:spark.metrics.conf.*.sink.prometheusServlet.path=/metrics/prometheus" \
    --properties="spark:spark.metrics.conf.master.sink.prometheusServlet.path=/metrics/master/prometheus" \
    --properties="spark:spark.metrics.conf.applications.sink.prometheusServlet.path=/metrics/applications/prometheus" \
    --spark-engine-version=latest \
    --staging-bucket=${DP_BUCKET} \
    --pools="name=${DP_POOLNAME},roles=default" \
    --setup-workload-identity \
    --history-server-cluster=${PHS_CLUSTER}


# Apply PodMonitoring to collect driver/executor metrics
kubectl apply -f manifests/podmonitoring.yaml -n ${DP_CLUSTER}

