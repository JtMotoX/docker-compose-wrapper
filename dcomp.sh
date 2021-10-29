#!/bin/bash

# MAKE SURE THIS IS A DOCKER DIRECTORY
docker-compose ps >/dev/null
if [[ $? -ne 0 ]]; then
	exit 1
fi

usage() {
	printf "Supported commands:\n"
	printf "\tstart|up\n"
	printf "\tstop|down\n"
	printf "\trestart\n"
	printf "\tbuild\n"
	printf "\tstatus\n"
	printf "\tlogs\n"
	printf "\tbash\n"
	printf "Supported flags:\n"
	printf "\t-d (do not tail logs)\n"
}

# GETS COMMAND ARGUMENT
CMD=$1
shift

# GET ARGUMENTS
while [ "$1" != "" ]; do
	case $1 in
		-d )					BACKGROUND=true
								;;
		-h | --help )			usage
								exit
								;;
		* )						echo "Unknown flag: '$1'"
								usage
								exit 1
	esac
	shift
done

# RESTART
if [[ "$CMD" == "restart" ]]; then
	docker-compose down 2>&1 | grep -v 'Network.*not found\.$'
	docker-compose up -d
	if [ ! $BACKGROUND ]; then
		docker-compose logs -f
	fi
	exit 0
fi

# STOP
if [[ "$CMD" == "stop" ]] || [[ "$CMD" == "down" ]]; then
	docker-compose down 2>&1 | grep -v 'Network.*not found\.$'
	exit 0
fi

# START
if [[ "$CMD" == "start" ]] || [[ "$CMD" == "up" ]]; then
	docker-compose up -d
	if [ ! $BACKGROUND ]; then
		docker-compose logs -f
	fi
	exit 0
fi

# BUILD
if [[ "$CMD" == "build" ]] || [[ "$CMD" == "rebuild" ]]; then
	set -e
	docker-compose build
	docker-compose down 2>&1 | grep -v 'Network.*not found\.$'
	docker-compose up -d
	if [ ! $BACKGROUND ]; then
		docker-compose logs -f
	fi
	exit 0
fi

# STATUS
if [[ "$CMD" == "status" ]] || [[ "$CMD" == "ps" ]]; then
	container_status=`docker-compose ps`
	running_count=`echo -e "$container_status" | wc -l`
	if [ $running_count -lt 3 ]; then
		echo "No Running Containers"
	else
		echo -e "$container_status"
	fi
	exit 0
fi

# LOGS
if [[ "$CMD" == "log" ]] || [[ "$CMD" == "logs" ]]; then
        docker-compose logs -f
        exit 0
fi

# BASH
if [[ "$CMD" == "bash" ]] || [[ "$CMD" == "sh" ]] || [[ "$CMD" == "ash" ]]; then
	container_status=`docker-compose ps | sed 's/^\s*Name\s.*$//' | sed 's/^-*$//' | sed -r '/^\s*$/d'`
	running_count=`echo -e "$container_status" | wc -l`
	if [ $running_count -eq 0 ]; then
		echo "No Running Containers"
	else
		container=`echo -e "$container_status" | grep -v 'db\|sql\|mariadb' | awk '{print $1}'`
		echo "Entering $container"
		docker exec -e COLUMNS="`tput cols`" -e LINES="`tput lines`" -it $container "$CMD"
	fi
	exit 0
fi


echo "Unknown argument '$CMD'"
usage
