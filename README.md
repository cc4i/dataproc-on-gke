# Dataproc on GKE

[Dataproc on GKE](https://cloud.google.com/dataproc/docs/guides/dpgke/dataproc-gke-overview) allows you to execute Big Data applications using the Dataproc jobs API on GKE clusters, which is managed offering. You probably can look into [Spark on Kubernetes Operator](https://github.com/GoogleCloudPlatform/spark-on-k8s-operator).

This repo tried to put all things and help you use Dataproc on GKE with success.

## About Cluster

### 1. GKE 
- 1.1 Using regional cluster for high availibility.
- 1.2 Enable 'Workload Identity' for fine-grained permission control.
- 1.2 Enable 'Managed Service for Prometheus' for better monitoring Spark jobs.



### 2. Dataproc 
- 2.1 Seperate funtional pods into different node pools, which means controller, driver and executor should be deployed into different node pool for better availibility and performance. 

Example:
```sh
gcloud dataproc clusters gke create ${DP_CLUSTER} \
    --region=${REGION} \
    --gke-cluster=${GKE_CLUSTER} \
    --gke-cluster-location=${GKE_LOCATION} \
    --pools="name=${DP_CTRL_POOLNAME},roles=default,machineType=${VM_TYPE}" \
    --pools="name=${DP_DRIVER_POOLNAME},min=1,max=3,roles=spark-driver,machineType=${VM_TYPE}" \
    --pools="name=${DP_EXEC_POOLNAME},min=1,max=10,roles=spark-executor,machineType=${VM_TYPE}"
```


- 2.2 Create seperate service account for controller, driver and executor.

- 2.3 Create different Dataproc cluster on the same GKE when your Spark jobs need different resource, such as high memory, GPU, etc.

- 2.4 Attach persistent histoy server to collect job related information and get better insight of detail. 

- 2.5 [Build and specify the custom image](https://cloud.google.com/dataproc/docs/guides/dpgke/dataproc-gke-custom-images#custom_container_image_requirements_and_settings) if need additional jars or configuration.  


- 2.6 Each SparkContext launches a [Web UI](https://spark.apache.org/docs/latest/web-ui.html), by default on port 4040, that displays useful information about the application. We can use port-forward through kubectl to access web/api through browser. 

- 2.7 We do have serveral options for monitoring dirver and executor in order to get realtime information of jobs.

- 2.8 Using different [Kubenetes volumes](https://spark.apache.org/docs/latest/running-on-kubernetes.html#using-kubernetes-volumes) for various cases, such as local SSD to spill data during shuffle for better performance, dynaimc allocation per executor, etc.

>logs - has been sent to Cloud Logging.

>metrics - can be monitoring by Cloud Monitoring, or choose different [Spark metrics providers](https://spark.apache.org/docs/latest/monitoring.html#metrics), such as JmxSink, PrometheusServlet, GraphiteSink, etc.

## Submit Spark Job

## Hands-on Lab

### 1. Provision a Dataproc virtul cluster for heavy workload
```sh
cd hack
# Provision GKE cluster if don't have a right one
./gke.sh
# Provision Dataproc cluster on top of GKE
./dp-large.sh 

```

### 2. Submit a Job
```sh
cd hack && ./env.sh
gcloud dataproc jobs submit spark \
    --region=${REGION} \
    --cluster=${DP_CLUSTER} \
    --properties="spark.app.name=SparkPi,spark.dynamicAllocation.maxExecutors=5" \
    --class=org.apache.spark.examples.SparkPi \
    --jars=../examples/spark-examples_2.12-3.1.3.jar \
    -- 200000

```

### 3. Monitoring driver & executor with JmxSink
```sh
cd hack
# Provision GKE cluster if don't have a right one
./gke.sh
# Provision Dataproc cluster on top of GKE
./dp-gmp.sh 

# Config scraping for Pod metrices
kubectl apply -f ../manifests/podmonitoring.yaml

# Submit a demo job
gcloud dataproc jobs submit spark \
    --region=${REGION} \
    --cluster=${DP_CLUSTER} \
    --properties="spark.app.name=SparkPi,spark.dynamicAllocation.maxExecutors=5" \
    --class=org.apache.spark.examples.SparkPi \
    --jars=../examples/spark-examples_2.12-3.1.3.jar \
    -- 100000

# Validate metrics with Prometheus UI
kubectl -n gmp-test port-forward svc/frontend 9090
# Brwose http://localhost:9090/

```

### 4. Monitoring driver & executor with PrometheusServlet
```sh
cd hack
# Provision GKE cluster if don't have a right one
./gke.sh
# Provision Dataproc cluster on top of GKE
./dp-promservlet.sh

# Config scraping for Pod metrices
kubectl apply -f ../manifests/podmonitoring-promservlet

# Submit a demo job
gcloud dataproc jobs submit spark \
    --region=${REGION} \
    --cluster=${DP_CLUSTER} \
    --properties="spark.app.name=SparkPi,spark.dynamicAllocation.maxExecutors=5" \
    --class=org.apache.spark.examples.SparkPi \
    --jars=../examples/spark-examples_2.12-3.1.3.jar \
    -- 100000

# Validate metrics with Prometheus UI
kubectl -n gmp-test port-forward svc/frontend 9090
# Brwose http://localhost:9090/

```


TODO:

- [x] Tidy scripts and testing.

