#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/redhat-gpte-devopsautomation/advdev_homework_template.git na311.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Set up Jenkins with sufficient resources
oc new-app jenkins-persistent -p ENABLE_OAUTH=true -p MEMORY_LIMIT=4Gi -n gsc-jenkins

# Create custom agent container image with skopeo
oc new-build -D $'FROM docker.io/openshift/jenkins-agent-maven-35-centos7:v3.11\nUSER root\nCMD ["yum", "install", "-y", "skopeo"]\nUSER 1001'

# Create pipeline build config pointing to the ${REPO} with contextDir `openshift-tasks`
echo "
apiVersion: v1
kind: BuildConfig
metadata: 
  name: openshift-tasks
spec:
  source:
    contextDir: openshift-tasks
  strategy:
    sourceStrategy:
      env:
        - name: "GUID"
	  value: $GUID
	- name: "REPO"
	  value: $REPO
	- name: "CLUSTER"
	  value: $CLUSTER
" | oc create -f -

# Make sure that Jenkins is fully up and running before proceeding!
while : ; do
  echo "Checking if Jenkins is Ready..."
  AVAILABLE_REPLICAS=$(oc get dc jenkins -n ${GUID}-jenkins -o=jsonpath='{.status.availableReplicas}')
  if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
    echo "...Yes. Jenkins is ready."
    break
  fi
  echo "...no. Sleeping 10 seconds."
  sleep 10
done
