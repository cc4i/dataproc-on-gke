#!/bin/sh
set -x 

if [ -z "${project_id}" ]
then
    echo "{project_id} is not defined."
    exit 1
fi

export PROJECT_ID=${project_id}
export LOCATION=us-central1
export GKE_CLUSTER=dataproc-gke

export DP_CLUSTER=dp-${GKE_CLUSTER}
export REGION=${LOCATION}
export PHS_CLUSTER=phs-server4dp

export DP_IMAGE_REPO=jigaree
export DP_BUCKET=cc-gcs-to-dataproc

export DP_POOLNAME=dp-np
export DP_CTRL_POOLNAME=dp-ctrl-np
export DP_DRIVER_POOLNAME=dp-driver-np
export DP_EXEC_POOLNAME=dp-exec-np