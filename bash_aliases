#!/bin/bash

function image {
	echo "    Project: $(kubectl config current-context)"
	if [ $# -eq 0 ]; then
		kubectl describe pods $(kubectl get pods | grep -v 'NAME' | awk '{ print $1 }') | grep 'Image:'
	else
        	kubectl describe pods $(kubectl get pods | grep $1 | awk '{ print $1 }') | grep 'Image:'
	fi
}

function showpod {
	echo "Project: $(kubectl config current-context)"
        kubectl get pods | grep $1
}

function gssh {
#connect to util-1 server of project you pass in
#eg. gssh tredium-scl-pharm-ltc
        ssh-add ~/.ssh/google_compute_engine
	zone=$(gcloud compute instances list --project ${1} --filter="Name:util-1" --format='value(zone)')
	echo "util-1 zone: ${zone}"
        gcloud compute ssh --zone ${zone} --project $1 util-1 --ssh-flag='-A'
}

function gscp {
#connect to util-1 server of project you pass in
#eg. gssh tredium-scl-pharm-ltc
        ssh-add ~/.ssh/google_compute_engine
	zone=$(gcloud compute instances list --project ${1} --filter="Name:util-1" --format='value(zone)')
	echo "util-1 zone: ${zone}"
        gcloud compute scp --zone ${zone} --project $1 util-1:${2} ${3}
}

function gport {
#connect to util-1 server of project you pass in, and setup port forward you set in second parameter
#eg gport tredium-scl-pharm-ltc "5432:pgpool:5432"
	ssh-add ~/.ssh/google_compute_engine
	zone=$(gcloud compute instances list --project ${1} --filter="Name:util-1" --format='value(zone  )')
	gcloud compute ssh --zone ${zone} --project $1 util-1 --ssh-flag='-A' --ssh-flag='-L' --ssh-flag="$2"
}

function gcon {
#connect to cluster-1 in given project. If parameter passed, use that cluster name instead of default cluster-1 (ie, internal-cluster in tredium-internal)
	zone=$(gcloud container clusters list --project ${1} | grep ${2:-cluster-1} | awk '{ print $2 }')
	gcloud container clusters get-credentials ${2:-cluster-1} --zone ${zone} --project ${1}
}

function __kube_ps1()
{
	if [ -e ${HOME}/.kube/config ]; then
		# Get current context
		CONTEXT=$(cat ${HOME}/.kube/config | grep "current-context:" | awk -F ": " '{ print $2 }')

		if [ ${CONTEXT} != "minikube" ]; then
			CONTEXT=$(echo ${CONTEXT} | awk -F "_" '{ print $2 }' | sed s/tredium-//g)
		fi

		if [ -n "$CONTEXT" ]; then
			echo "(k8s: ${CONTEXT})"
		fi
	else
		echo ""
	fi
}

function run_pg()
{
	docker run -d -p ${2:-5432}:5432 -v $HOME/sql:/mnt/startup -e POSTGRES_PASSWORD=password --name=${1:-postgres} docker.tredium.com/tredium/alpine-postgres:9.6.8
}

function restore_pg()
{
	pg_restore -h localhost -d nadb -U postgres -p ${2:-5432} -W -Fc < ${1:-nadb.dump}
}
