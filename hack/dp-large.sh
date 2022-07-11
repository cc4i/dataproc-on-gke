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

# Provision service account & grant proper permission


# Create DP cluster with specific properties
# >1. Using PrometheusServerlet for Prometheus metrics.
# >2. Attach history server.
# >3. Provision seperate node pools for controller, driver and executor into same zone for high performance.
# >4. Create different service account for controller, driver and executor
# >

gcloud dataproc clusters gke create ${CLUSTER_NAME} \
  --region=${REGION} \
  --gke-cluster=${GKE_CLUSTER_NAME} \
  --gke-cluster-location=${REGION} \
  --spark-engine-version=latest \
  --staging-bucket=${DP_BUCKET}  \
  --setup-workload-identity \
  --properties="spark:spark.kubernetes.driver.annotation.prometheus.io/scrape=true" \
  --properties="spark:spark.kubernetes.driver.annotation.prometheus.io/path=/metrics/executors/prometheus/" \
  --properties="spark:spark.kubernetes.driver.annotation.prometheus.io/port=4040" \
  --properties="spark:spark.kubernetes.driver.service.annotation.prometheus.io/scrape=true" \
  --properties="spark:spark.kubernetes.driver.service.annotation.prometheus.io/path=/metrics/prometheus/" \
  --properties="spark:spark.kubernetes.driver.service.annotation.prometheus.io/port=4040" \
  --properties="spark:spark.ui.prometheus.enabled=true" \
  --properties="spark:spark.metrics.conf.*.sink.prometheusServlet.class=org.apache.spark.metrics.sink.PrometheusServlet" \
  --properties="spark:spark.metrics.conf.*.sink.prometheusServlet.path=/metrics/prometheus" \
  --properties="spark:spark.metrics.conf.master.sink.prometheusServlet.path=/metrics/master/prometheus" \
  --properties="spark:spark.metrics.conf.applications.sink.prometheusServlet.path=/metrics/applications/prometheus" \
  --history-server-cluster=${PHS_CLUSTER_NAME} \
  --pools="name=${DP_POOLNAME},roles=default" \
  --pools="name=${DP_CTRL_POOLNAME},roles=default,machineType=${VM_TYPE}" \
  --pools="name=${DP_DRIVER_POOLNAME},min=1,max=3,roles=spark-driver,machineType=${VM_TYPE}" \
  --pools="name=${DP_EXEC_POOLNAME},min=1,max=10,roles=spark-executor,machineType=${VM_TYPE}" \
  --properties="dataproc:dataproc.gke.agent.google-service-account=${DP_GSA}" \
  --properties="dataproc:dataproc.gke.spark.driver.google-service-account=${DP_GSA}" \
  --properties="dataproc:dataproc.gke.spark.executor.google-service-account=${DP_GSA}" \
  --properties="spark:spark.kubernetes.executor.volumes.hostPath.spark-local-dir-1.mount.path=/var/data/spark-1" \
  --properties="spark:spark.kubernetes.executor.volumes.hostPath.spark-local-dir-1.options.path=/mnt/disks/ssd0"
