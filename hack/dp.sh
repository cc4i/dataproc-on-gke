
gcloud dataproc clusters create phs-server4dp-gpm \
    --region=us-central1 \
    --single-node \
    --enable-component-gateway \
    --properties=spark:spark.history.fs.logDirectory=gs://cc-gcs-to-dataproc/phs/spark-job-history


DP_CLUSTER=dp-gpm2 \
  REGION=us-central1 \
  GKE_CLUSTER=dataproc-gke-gpm \
  BUCKET=cc-gcs-to-dataproc \
  DP_POOLNAME=dp-noodpool2
  PHS_CLUSTER=phs-server4dp-gpm

gcloud dataproc clusters gke create ${DP_CLUSTER} \
    --region=${REGION} \
    --gke-cluster=${GKE_CLUSTER} \
    --gke-cluster-location=us-central1-c \
    --properties="spark:spark.kubernetes.container.image=us-central1-docker.pkg.dev/play-with-anthos-340801/jigaree/dataproc-test:latest" \
    --properties="spark:spark.metrics.conf.*.sink.jmx.class=org.apache.spark.metrics.sink.JmxSink" \
    --properties="spark:spark.ui.prometheus.enabled=true" \
    --properties="spark:spark.metrics.conf.master.source.jvm.class=org.apache.spark.metrics.source.JvmSource" \
    --properties="spark:spark.metrics.conf.worker.source.jvm.class=org.apache.spark.metrics.source.JvmSource" \
    --properties="spark:spark.metrics.conf.driver.source.jvm.class=org.apache.spark.metrics.source.JvmSource" \
    --properties="spark:spark.metrics.conf.executor.source.jvm.class=org.apache.spark.metrics.source.JvmSource" \
    --properties="spark:spark.driver.extraJavaOptions=-javaagent:/opt/spark/jars/jmx_prometheus_javaagent-0.17.0.jar=9091:/usr/lib/spark/conf/prometheus-config.yml" \
    --properties="spark:spark.executor.extraJavaOptions=-javaagent:/opt/spark/jars/jmx_prometheus_javaagent-0.17.0.jar=9091:/usr/lib/spark/conf/prometheus-config.yml" \
    --spark-engine-version=latest \
    --staging-bucket=${BUCKET} \
    --pools="name=${DP_POOLNAME},roles=default" \
    --setup-workload-identity \
    --history-server-cluster=${PHS_CLUSTER}



kubectl apply -f podmonitoring.yaml -n dp-gpm2

gcloud dataproc clusters gke create ${CLUSTER_NAME} \
--project=${PROJECT} \
--region=${REGION} \
--gke-cluster=${GKE_CLUSTER_NAME} \
--gke-cluster-location=${REGION} \
--spark-engine-version=3.1 \
--namespace=spark31-highmem \
--staging-bucket=${DATAPROC_BUCKET} \
--setup-workload-identity \
--history-server-cluster=${PHS_CLUSTER_NAME} \
--pools="name=control-pool,min=0,max=3,roles=default,machineType=e2-medium,locations=${ZONE}" \
--pools="name=driver-pool,min=0,max=10,roles=spark-driver,machineType=n2-highmem-4,locations=${ZONE},minCpuPlatform=AMD Milan,preemptible=true" \
--pools="name=spark-highmem-pool,roles=spark-executor,min=0,max=13,roles=spark-executor,machineType=n2-highmem-16,locations=${ZONE},minCpuPlatform=AMD Milan,preemptible=true,localSsdCount=1" \
--properties="dataproc:dataproc.gke.agent.google-service-account=${DP_GSA}" \
--properties="dataproc:dataproc.gke.spark.driver.google-service-account=${DP_GSA}" \
--properties="dataproc:dataproc.gke.spark.executor.google-service-account=${DP_GSA}"
--properties="spark:spark.kubernetes.executor.volumes.hostPath.spark-local-dir-1.mount.path=/var/data/spark-1" \
--properties="spark:spark.kubernetes.executor.volumes.hostPath.spark-local-dir-1.options.path=/mnt/disks/ssd0" \
