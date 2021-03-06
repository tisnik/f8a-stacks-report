#!/bin/bash

set -e
set -x

# test coverage threshold
COVERAGE_THRESHOLD=60

export TERM=xterm
TERM=${TERM:-xterm}

# set up terminal colors
NORMAL=$(tput sgr0)
RED=$(tput bold && tput setaf 1)
GREEN=$(tput bold && tput setaf 2)
YELLOW=$(tput bold && tput setaf 3)

printf "%sShutting down docker-compose ..." "${NORMAL}"
gc() {
  retval=$?
  docker-compose -f docker-compose.yml down -v || :
  rm -rf venv/
  exit $retval
}

trap gc EXIT SIGINT

function start_postgres {
    #pushd local-setup/
    echo "Invoke Docker Compose services"
    docker-compose -f docker-compose.yml up  --force-recreate -d
    #popd
}

start_postgres

function prepare_venv() {
    VIRTUALENV=$(which virtualenv) || :
    if [ -z "$VIRTUALENV" ]
    then
        # python34 which is in CentOS does not have virtualenv binary
        VIRTUALENV=$(which virtualenv-3)
    fi

    ${VIRTUALENV} -p python3 venv && source venv/bin/activate
    if [ $? -ne 0 ]
    then
        printf "%sPython virtual environment can't be initialized%s" "${RED}" "${NORMAL}"
        exit 1
    fi
}
PYTHONPATH=$(pwd)/f8a_report/
export PYTHONPATH

export POSTGRESQL_USER='coreapi'
export POSTGRESQL_PASSWORD='coreapipostgres'
export POSTGRESQL_DATABASE='coreapi'
export PGBOUNCER_SERVICE_HOST='0.0.0.0'
export PGPORT="5432"
export REPORT_BUCKET_NAME="not-set"
export AWS_S3_ACCESS_KEY_ID="not-set"
export AWS_S3_SECRET_ACCESS_KEY="not-set"
export AWS_S3_REGION="not-set"

prepare_venv
pip3 install -r requirements.txt
pip3 install -r tests/requirements.txt
pip3 install $(pwd)/.

python3 "$(which pytest)" --cov=f8a_report/ --cov-report term-missing --cov-fail-under=$COVERAGE_THRESHOLD -vv tests

codecov --token=d6bd6983-0bad-4eed-b8e3-9fd1d5199257
printf "%stests passed%s\n\n" "${GREEN}" "${NORMAL}"

