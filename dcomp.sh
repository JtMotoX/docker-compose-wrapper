#!/bin/bash

# CHECK IF DOCKER-COMPOSE IS INSTALLED
if ! type docker-compose &>/dev/null; then
	if type nerdctl &>/dev/null; then
		function docker-compose() { nerdctl compose "$@"; }
	else
		echo "docker-compose not found"
		exit 1
	fi
fi

usage() {
	printf "Supported commands:\n"
	printf "\tstart|up\n"
	printf "\t\t-d (do not tail logs)\n"
	printf "\tstop|down\n"
	printf "\trestart\n"
	printf "\t\t-d (do not tail logs)\n"
	printf "\tbuild\n"
	printf "\t\t-p|--pull (pull image)\n"
	printf "\t\t-d (do not tail logs)\n"
	printf "\tstatus\n"
	printf "\tlogs\n"
	printf "\tbash|ash|sh\n"
	printf "\tupdate\n"
}

# GETS COMMAND ARGUMENT
CMD=$1
shift

if [ "${CMD}" != "update" ]; then
	# MAKE SURE THIS IS A DOCKER DIRECTORY
	docker-compose ps >/dev/null
	if [[ $? -ne 0 ]]; then
		exit 1
	fi
fi

# SETS SOME DEFAULT VARIABLES
BACKGROUND=false
PULL=false

# GET ARGUMENTS
while [ "$1" != "" ]; do
	case $1 in
		-d )
			BACKGROUND=true
			;;
		-p | --pull)
			PULL=true
			;;
		-h | --help )
			usage
			exit
			;;
		* )
			echo "Unknown flag: '$1'"
			usage
			exit 1
	esac
	shift
done

build() { docker-compose up -d --build $1; }
stop() { docker-compose down 2>&1 | grep -v 'Network.*not found\.$'; }
start() { docker-compose up -d; }
logs() { docker-compose logs -f; }
status() { docker-compose ps | grep -v -i -E '^\s*Name\s.*' | grep -v -E '^-*$' | grep -v '^\s*$'; }

# RESTART
if [[ "${CMD}" == "restart" ]]; then
	stop
	start
	[ "${BACKGROUND}" = "false" ] && logs
	exit 0
fi

# STOP
if [[ "${CMD}" == "stop" ]] || [[ "${CMD}" == "down" ]]; then
	stop
	exit 0
fi

# START
if [[ "${CMD}" == "start" ]] || [[ "${CMD}" == "up" ]]; then
	start
	[ "${BACKGROUND}" = "false" ] && logs
	exit 0
fi

# BUILD
if [[ "${CMD}" == "build" ]] || [[ "${CMD}" == "rebuild" ]]; then
	set -e
	BUILD_ARGS=""
	[ "${PULL}" = "true" ] && BUILD_ARGS="${BUILD_ARGS} --pull always"
	build "${BUILD_ARGS}"
	[ "${BACKGROUND}" = "false" ] && logs
	exit 0
fi

# STATUS
if [[ "${CMD}" == "status" ]] || [[ "${CMD}" == "ps" ]]; then
	container_status="$(status)"
	[ "${container_status}" = "" ] && { echo "No Running Containers"; exit 0; }
	echo "${container_status}"
	exit 0
fi

# LOGS
if [[ "${CMD}" == "log" ]] || [[ "${CMD}" == "logs" ]]; then
	logs
	exit 0
fi

# BASH
if [[ "${CMD}" == "bash" ]] || [[ "${CMD}" == "sh" ]] || [[ "${CMD}" == "ash" ]]; then
	container_list=$(status | grep -i -E ' (Up|running) ' | awk '{print $1}' )
	[ "${container_list}" = "" ] && { echo "No Running Containers"; exit 0; }
	if [ $(echo "${container_list}" | wc -l) -gt 1 ]; then
		container_list=$(echo "${container_list}" | grep -v -E 'database|db|sql')
	fi
	container=$(echo "${container_list}" | head -n1)
	echo "Entering ${container}"
	docker exec -e COLUMNS="$(tput cols)" -e LINES="$(tput lines)" -it ${container} "${CMD}"
	exit 0
fi

if [ "${CMD}" = "update" ]; then
	DCOMP_EXECUTABLE_PATH="$(which dcomp)"
	if [ "${DCOMP_EXECUTABLE_PATH}" = "" ]; then echo "which dcomp: not found"; exit 1; fi
	DCOMP_REAL_PATH="$(ls -l ${DCOMP_EXECUTABLE_PATH} | awk '{print $NF}')"
	if [ ! -f "${DCOMP_REAL_PATH}" ]; then echo "dcomp file not found: '${DCOMP_REAL_PATH}'"; exit 1; fi
	DCOMP_REAL_DIR="$(dirname "${DCOMP_REAL_PATH}")"
	if [ ! -d "${DCOMP_REAL_DIR}" ]; then echo "dcomp directory not found: '${DCOMP_REAL_DIR}'"; exit 1; fi
	cd "${DCOMP_REAL_DIR}"
	SUDO_PREFIX=""
	if ! git status >/dev/null 2>/tmp/dcomp-update.log; then
		if cat /tmp/dcomp-update.log | grep 'detected dubious ownership' >/dev/null; then
			SUDO_PREFIX="sudo"
		else
			cat /tmp/dcomp-update.log
			exit 1
		fi
	fi
	LATEST_COMMIT_BEFORE="$(${SUDO_PREFIX} git log -1 --format=%cd)"
	if ! ${SUDO_PREFIX} git pull; then
		echo "There was an error updating"
		exit 1
	fi
	printf "BEFORE:\t${LATEST_COMMIT_BEFORE}\n"
	printf "AFTER:\t${LATEST_COMMIT_BEFORE}\n"
	exit 0
fi

echo "Unknown argument '${CMD}'"
usage
