#!/usr/bin/env bash


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

################
#              #
# PSQL Helpers #
#              #
################

function run_pg()
{
	docker run -d -p ${2:-5432}:5432 -v $HOME/sql:/mnt/startup -e POSTGRES_PASSWORD=password --name=${1:-postgres} postgres:alpine
}

#################
# MYSQL HELPERS #
#################

MYSQL_VERSION=5.6

function start_sezzle_db()
{
	local mount_dir=$HOME/mysqlmnt

	if [ ! -d $mount_dir ]; then
		mkdir $mount_dir
	fi

	cmd='echo "GRANT ALL ON *.* TO '\''sezzle'\''@'\''%'\''; CREATE DATABASE IF NOT EXISTS currencycloud; CREATE DATABASE IF NOT EXISTS eft; CREATE DATABASE IF NOT EXISTS card; CREATE DATABASE IF NOT EXISTS marqeta; CREATE DATABASE IF NOT EXISTS nacha; CREATE DATABASE IF NOT EXISTS test; CREATE DATABASE IF NOT EXISTS vault; CREATE DATABASE IF NOT EXISTS sezzle; CREATE DATABASE IF NOT EXISTS sezzle_card; CREATE DATABASE IF NOT EXISTS product_events_test; CREATE DATABASE IF NOT EXISTS product_events; CREATE DATABASE IF NOT EXISTS card_processor; CREATE DATABASE IF NOT EXISTS bank_provider; GRANT ALL ON \`currencycloud\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`eft\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`card\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`marqeta\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`nacha\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`product_events_test\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`test\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`product_events\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`sezzle_card\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`sezzle\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`bank_provider\`.* TO '\''sezzle'\''@'\''%'\''; GRANT ALL ON \`card_processor\`.* TO '\''sezzle'\''@'\''%'\'';  GRANT ALL ON \`vault\`.* TO '\''sezzle'\''@'\''%'\''; " > /docker-entrypoint-initdb.d/init.sql; /usr/local/bin/docker-entrypoint.sh mysqld'

	docker run -d -p 3306:3306 \
		-e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
		-e MYSQL_ROOT_HOST='%' \
		-e MYSQL_USER=sezzle \
		-e MYSQL_PASSWORD=Testing123 \
		--mount 'type=volume,volume-driver=local,volume-opt=device=:'${mount_dir}',dst=/app:,volume-opt=type=nfs,"volume-opt=o=addr=host.docker.internal,rw,nolock,hard,nointr,nfsvers=3"' \
		--name=mysql-sez \
		mysql:${MYSQL_VERSION} \
		/bin/sh -c "${cmd}"
}

		# --mount 'type=volume,volume-driver=local,volume-opt=device=:/System/Volumes/Data/Users/nhalm/mysqlmnt,dst=/app:,volume-opt=type=nfs,"volume-opt=o=addr=host.docker.internal,rw,nolock,hard,nointr,nfsvers=3"' \
function restart_sezzle_db()
{
	docker rm -fv mysql-sez
	start_sezzle_db
}

function mysql_local() {
	docker run --rm \
		-it \
		--network=host \
		mysql:${MYSQL_VERSION} \
		mysql -u sezzle -D sezzle --protocol=tcp -p${MYSQL_PASSWORD}
}

function mysql_s() {
	local this_host=${MYSQL_HOST:=localhost}
	local this_username=${MYSQL_USER:=sezzle}

	echo ${this_host}
	echo ${this_username}

	docker run --rm \
		-it \
		--network=host \
		mysql:${MYSQL_VERSION} \
		mysql -h ${this_host} -u ${this_username} --protocol=tcp -p
}

function mysql_dump() {
	local this_host=${MYSQL_HOST:=localhost}
	local this_username=${MYSQL_USER:=sezzle}

	echo ${this_host}
	echo ${this_username}

	docker run --rm \
		-it \
		--network=host \
		-v $(pwd):/dump \
		mysql:${MYSQL_VERSION} \
		/bin/bash -c "mysqldump -h${this_host} -u ${this_username} --protocol=tcp -p${MYSQL_PASSWORD} -T --fields-enclosed-by=\" --lock-tables=false $@ > /dump/dump_out.sql"
		# /bin/bash -c "mysqldump -h${this_host} -u ${this_username} --protocol=tcp -p${MYSQL_PASSWORD} ${args} > /dump/dump_out.sql"
}

function mysql_restore() {
	docker exec -i \
		--network=host \
		mysql:${MYSQL_VERSION} \
		/bin/bash -c "mysql -h localhost -u sezzle -D sezzle --protocol=tcp -p${MYSQL_PASSWORD} < $1"
}

##############
#            #
# Go Helpers #
#            #
##############

function golangci_lint() {
	 docker run --rm \
                -v $(pwd):/app \
                -v ${GOPATH}/pkg/mod:/go/pkg/mod \
                -w /app \
                golangci/golangci-lint:latest golangci-lint run -v
}

#################
#               #
# Miscellaneous #
#               #
#################

function get_platform()
{
	local unameOut="$(uname -s)"
	local maching="UNKNOWN"

	case "${unameOut}" in
	    Linux*)     machine=Linux;;
	    Darwin*)    machine=Mac;;
	    CYGWIN*)    machine=Cygwin;;
	    MINGW*)     machine=MinGw;;
	    *)          machine="UNKNOWN:${unameOut}"
	esac
	echo ${machine}
}

#########
#       #
#  AWS  #
#       #
#########

function aws_mfa(){
	unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
	local token="$1"
	local sn=030664766007

	echo -n "MFA Token: "
	read token

	local result=$(aws sts get-session-token --serial-number arn:aws:iam::$sn:mfa/$AWS_USERNAME --token-code "$token")
	export AWS_ACCESS_KEY_ID=$(echo "$result" | jq -r '.Credentials.AccessKeyId')
	export AWS_SECRET_ACCESS_KEY=$(echo "$result" | jq -r '.Credentials.SecretAccessKey')
	export AWS_SESSION_TOKEN=$(echo "$result" | jq -r '.Credentials.SessionToken')
}

function login_data_lake() {
	if [[ -z "${AWS_SESSION_TOKEN}" ]]; then
		aws_mfa
	fi

	local result=$(aws redshift get-cluster-credentials \
			--cluster-identifier data-lake \
			--db-user $AWS_USERNAME \
			--db-name dev \
			--duration-seconds 3600 \
			--auto-create \
			--db-groups payments analysis)

	export PGUSER=$(echo "$result" | jq -r '.DbUser')
	export PGPASSWORD=$(echo "$result" | jq -r '.DbPassword')

	echo 'You can view your temporary password via `echo $PGPASSWORD`'
}


function login_masked_data() {
	if [[ -z "${AWS_SESSION_TOKEN}" ]]; then
		aws_mfa
	fi

	local result=$(aws redshift get-cluster-credentials \
			--cluster-identifier data-lake \
			--db-user ${AWS_USERNAME} \
			--db-name staging \
			--duration-seconds 3600 \
			--auto-create \
			--db-groups analysis)

	export MASK_USER=$(echo "$result" | jq -r '.DbUser')
	export MASK_PASS=$(echo "$result" | jq -r '.DbPassword')

	echo 'You can connect via if on the VPN: `pgcli -h data-lake.sezzle.internal -p 5439 -U "$MASK_USER" staging`'
	echo 'You can view your temporary password via `echo $MASK_PASS`'
}

function pgcli_rs() {
	docker run --rm -it \
		--network=host \
		-v $(pwd):/shared \
		-v ${HOME}/.psql_history/:/root/.psql_history/ \
		-v ${HOME}/.psqlrc:/root/.psqlrc \
		-e PGUSER \
		-e PGPASSWORD \
		postgres:alpine psql dev -h data-lake.sezzle.internal -p 5439 $@
}

function golangci_lint() {
	docker run --rm \
		-v $(pwd):/app \
		-v ${GOPATH}/pkg/mod:/go/pkg/mod \
		-w /app \
		golangci/golangci-lint:latest-alpine golangci-lint run -v
}

function xgolangci_lint() {
	docker run --rm \
		-v $(pwd):/builds/pkg/sezgateway/.git/ \
		registry.gitlab.com/gitlab-org/gitlab-build-images:golangci-lint-alpine \
		golangci-lint run --out-format code-climate | tee gl-code-quality-report.json | jq -r '.[] | "\(.location.path):\(.location.lines.begin) \(.description)"'
}
