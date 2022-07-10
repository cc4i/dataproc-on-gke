
gcloud beta container --project "play-with-anthos-340801" clusters create "dataproc-gke-gpm" \
    --zone "us-central1-c" \
    --no-enable-basic-auth \
    --cluster-version "1.22.8-gke.202" \
    --release-channel "regular" \
    --machine-type "e2-medium" \
    --image-type "COS_CONTAINERD" \
    --disk-type "pd-standard" \
    --disk-size "100" \
    --metadata disable-legacy-endpoints=true \
    --scopes "https://www.googleapis.com/auth/cloud-platform" \
    --num-nodes "2" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM \
    --enable-ip-alias --network "projects/play-with-anthos-340801/global/networks/default" \
    --subnetwork "projects/play-with-anthos-340801/regions/us-central1/subnetworks/default" \
    --no-enable-intra-node-visibility \
    --default-max-pods-per-node "16" \
    --no-enable-master-authorized-networks \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
    --enable-autoupgrade \
    --enable-autorepair \
    --max-surge-upgrade 1 \
    --max-unavailable-upgrade 0 \
    --enable-managed-prometheus --workload-pool "play-with-anthos-340801.svc.id.goog" \
    --enable-shielded-nodes \
    --node-locations "us-central1-c"

# Install Prometheus UI
kubectl create ns gmp-test

gcloud iam service-accounts create gmp-test-sa \
&&
gcloud iam service-accounts add-iam-policy-binding \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:play-with-anthos-340801.svc.id.goog[gmp-test/default]" \
  gmp-test-sa@play-with-anthos-340801.iam.gserviceaccount.com \
&&
kubectl annotate serviceaccount \
  --namespace gmp-test \
  default \
  iam.gke.io/gcp-service-account=gmp-test-sa@play-with-anthos-340801.iam.gserviceaccount.com

gcloud projects add-iam-policy-binding play-with-anthos-340801 \
  --member=serviceAccount:gmp-test-sa@play-with-anthos-340801.iam.gserviceaccount.com \
  --role=roles/monitoring.viewer

curl https://raw.githubusercontent.com/GoogleCloudPlatform/prometheus-engine/v0.4.1/examples/frontend.yaml |
sed 's/\$PROJECT_ID/play-with-anthos-340801/' |
kubectl apply -n gmp-test -f -