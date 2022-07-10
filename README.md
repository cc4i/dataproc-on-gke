# Dataproc on GKE

[Dataproc on GKE](https://cloud.google.com/dataproc/docs/guides/dpgke/dataproc-gke-overview) allows you to execute Big Data applications using the Dataproc jobs API on GKE clusters, which is managed offering. You probably can look into [Spark on Kubernetes Operator](https://github.com/GoogleCloudPlatform/spark-on-k8s-operator).

This repo tried to put all things and help you use Dataproc on GKE with success.

## Preparing Cluster

### 1. GKE 
- 1.1 Enable 'Workload Identity' for fine-grained permission control.
- 1.2 Enable 'Managed Service for Prometheus' for better monitoring Spark jobs.
- 1.3 

```sh
# Review scripts and modify something as per request
cd hack && ./cluster.sh
```

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


-2.2 Create seperate service account for controller, driver and executor.

-2.3 Create different Dataproc cluster on the same GKE when your Spark jobs need different resource, such as high memory, GPU, etc.

-2.4 Attach persistent histoy server to collect job related information and get better insight of detail. 

-2.5 [Build and specify the custom image](https://cloud.google.com/dataproc/docs/guides/dpgke/dataproc-gke-custom-images#custom_container_image_requirements_and_settings) if need additional jars or configuration.  
