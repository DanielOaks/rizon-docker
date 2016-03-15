#!/bin/bash


# Example: build ircd 0
function build {
	case "$1" in
	ircd)
		declare ircdtype="SERVER_$2_IRCD"
		if [ ${!ircdtype} = "plexus3" -o ${!ircdtype} = "plexus4" ]; then
			cp config.sh "${!ircdtype}/"
			docker build -t "server_${2}_ircd" "./${!ircdtype}"
			rm "${!ircdtype}/config.sh"
			echo "Container 'server_${2}_ircd' is built."
		else
			echo "Error: container type '${!ircdtype}' does not exist."
		fi
		;;
	services)
		declare servicestype="SERVER_$2_SERVICES"
		if [ ${!servicestype} = "anope1" -o ${!servicestype} = "anope2" ]; then
			cp config.sh "${!servicestype}/"
			docker build -t "server_${2}_services" "./${!servicestype}"
			rm "{$!servicestype}/config.sh"
			echo "Container 'server_${2}_services' is built."
		else
			echo "Error: container type '${!servicestype}' does not exist."
		fi
		;;
	db)
		if [ $2 -eq 0 ]; then
			cp config.sh mysqld/
			docker build -t server_0_db "./mysqld"
			rm mysqld/config.sh
			echo "Container 'server_0_db' is built."
		else
			echo "Error: container type 'db' can be built only for 'server 0'."
		fi
		;;
	acid)
		if [ $2 -eq 0 ]; then
			if [ $SERVER_0_ACID -eq 1 ]; then
				build db 0
				cp config.sh acid/
				docker build -t "server_0_acid" acid/
				rm acid/config.sh
				echo "Container 'server_0_acid' is built."
			fi
		else
			echo "Error: container type 'acid' can be built only for 'server 0'."
		fi
		;;
	moo)
		if [ $2 -eq 0 ]; then
			if [ $SERVER_0_MOO -eq 1 ]; then
				build db 0
				cp config.sh moo/
				docker build -t server_0_moo moo/
				rm moo/config.sh
				echo "Container 'server_0_moo' is built."
			fi
		else
			echo "Error: container type 'moo' can be built only for 'server 0'."
		fi
		;;
	users)
		declare users="SERVER_$2_USERS"
		if [ ${!users} -gt 0 ]; then
			cp config.sh users/
			docker build -t "server_${2}_users" users/
			rm users/config.sh
			echo "Container 'server_${2}_users' is built."
		fi
		;;
	server)
		build ircd $2
		build services $2
		build acid $2
		build moo $2
		build users $2
		echo "All containers of 'server $2' are built."
		;;
	all)
		for i in `seq 0 $[${NUMBER_OF_SERVERS}-1]`; do
			build server $i
		done
		echo "All servers are built."
		;;
	esac
}


# Example: create ircd 0
function create {
	if [ ! -f data/volume_created ]; then
		docker create -v ${PWD}/data:/data --name rizon_data centos:7 /bin/true
		touch data/volume_created
		echo "Data volume container 'rizon_data' created."
	fi
	case "$1" in
	ircd)
		declare ircdtype="SERVER_${2}_IRCD"
		if [ ${!ircdtype} = "plexus3" -o ${!ircdtype} = "plexus4" ]; then
			name="server_${2}_ircd"
			docker create -it --volumes-from rizon_data -p "663${2}:663${2}" -p "666${2}:666${2}" --name $name $name
			echo "Container '$name' created."
		else
			echo "Error: '${!ircdtype}' is not a supported ircd type."
		fi
		;;
	services)
		declare servicestype="SERVER_${2}_SERVICES"
		if [ ${!servicestype} = "anope1" -o ${!servicestype} = "anope2" ]; then
			name="server_${2}_services"
			docker create -it --net=container:server_${2}_ircd --name $name $name
			echo "Container '$name' created."
		elif [ ${!servicestype} != "none" ]; then
			echo "Error: '$3' is not a supported services type."
		fi
		;;
	db)
		name="server_${2}_db"
		docker create -it -e MYSQL_ALLOW_EMPTY_PASSWORD=yes --net=container:server_${2}_ircd --name $name $name
		echo "Container '$name' created."
		;;
	acid)
		declare servicestype="SERVER_${2}_SERVICES"
		if [ ${!servicestype} = "anope1" -o ${!servicestype} = "anope2" ]; then
			docker ps -a | grep server_${2}_db
			if [ $? -ne 0 ]; then
				create db $2
			fi
			name="server_${2}_acid"
			docker create -it --net=container:server_${2}_ircd --name $name $name
			echo "Container '$name' created."
		else
			echo "Error: There is no acid container built against anope version '$3'."
		fi
		;;
	moo)
		docker ps -a | grep server_${2}_db
		if [ $? -ne 0 ]; then
			create db $2
		fi
		name="server_${2}_moo"
		docker create -it --net=container:server_${2}_ircd --name $name $name
		echo "Container '$name' created."
		;;
	users)
		name="server_${2}_users"
		docker create -it --name $name $name
		echo "Container '$name' created."
		;;
	server)
		if [ $2 -eq 0 ]; then
			create ircd 0
			create services 0
			if [ $SERVER_0_ACID -eq 1 -a $SERVER_0_SERVICES != "none" ]; then
				create acid 0
			fi
			if [ $SERVER_0_MOO -eq 1 ]; then
				create moo 0
			fi
			if [ $SERVER_0_USERS -gt 0 ]; then
				create users 0
			fi
		elif [ $2 -gt 0 ]; then
			declare users="SERVER_${2}_USERS"
			create ircd $2
			if [ ${!users} -gt 0 ]; then
				create users $2
			fi
		fi
		echo "All containers of 'server $2' created."
		;;
	all)
		for i in `seq 0 $[${NUMBER_OF_SERVERS}-1]`; do
			create server $i
		done
		echo "All servers created."
		;;
	esac
}


# Example: start ircd 0
function start {
    name="server_$2_$1"
    echo "ircd services acid moo users" | grep -q "\b$1\b"
    if [ $? -eq 0 ]; then
        docker start $name
        echo "Container '$name' started."
    elif [ $1 = "server" ]; then
        if [ $2 -eq 0 ]; then
			docker start server_0_ircd
            if [ $SERVER_0_SERVICES != "none" ]; then
                docker start server_0_services
            fi
            if [ $SERVER_0_ACID -eq 1 ]; then
				docker start server_0_db
				SERVER_0_DB_STARTED=1
                docker start server_0_acid
            fi
            if [ $SERVER_0_MOO -eq 1 ]; then
				if [ $SERVER_0_DB_STARTED -ne 1 ]; then
					docker start server_0_db
				fi
                docker start server_0_moo
            fi
            if [ $SERVER_0_USERS -gt 0 ]; then
                docker start server_0_users
            fi
        elif [ $2 -gt 0 ]; then
            declare users="SERVER_${2}_USERS"
            docker start server_${2}_ircd
            if [ ${!users} -gt 0 ]; then
                docker start server_${2}_users
            fi
        fi
        echo "All containers of 'server $2' started."
    elif [ $1 = "all" ]; then
        for i in `seq 0 $[${NUMBER_OF_SERVERS}-1]`; do
            start server $i
        done
        echo "All servers started."
    else
        echo "Error: container '$name' does not exist."
    fi
}


# Example: stop ircd 0
function stop {
    name="server_$2_$1"
    echo "ircd services acid moo users" | grep -q "\b$1\b"
	if [ $? -eq 0 ]; then
        docker stop $name
        echo "Container '$name' stopped."
    elif [ $1 = "server" ]; then
        if [ $2 -eq 0 ]; then
            if [ $SERVER_0_USERS -gt 0 ]; then
                docker stop server_0_users
            fi
            if [ $SERVER_0_ACID -eq 1 ]; then
                docker stop server_0_acid
				docker stop server_0_db
				SERVER_0_DB_STOPPED=1
            fi
            if [ $SERVER_0_MOO -eq 1 ]; then
                docker stop server_0_moo
				if [ $SERVER_0_DB_STOPPED -ne 1 ]; then
					docker stop server_0_db
				fi
            fi
            if [ $SERVER_0_SERVICES != "none" ]; then
                docker stop server_0_services
            fi
            docker stop server_0_ircd
        elif [ $2 -gt 0 ]; then
            declare users="SERVER_${2}_USERS"
            if [ ${!users} -gt 0 ]; then
                docker stop server_${2}_users
            fi
            docker stop server_${2}_ircd
        fi
        echo "All containers of 'server $2' stopped."
    elif [ $1 = "all" ]; then
        for i in `seq 0 $[${NUMBER_OF_SERVERS}-1]`; do
            stop server $i
        done
        echo "All servers stopped."
    else
        echo "Error: container '$name' does not exist."
    fi
}


# Example: restart ircd 0
function restart {
	stop $1 $2
	start $1 $2
}


# Example: delete ircd 0
function delete {
	name="server_$2_$1"
	echo "ircd services acid moo users" | grep -q "\b$1\b"
	if [ $? -eq 0 ]; then
		docker rm -f $name
		echo "Container '$name' deleted."
	elif [ $1 = "server" ]; then
		if [ $2 -eq 0 ]; then
			if [ $SERVER_0_USERS -gt 0 ]; then
				docker rm -f server_0_users
			fi
            if [ $SERVER_0_ACID -eq 1 ]; then
                docker rm -f server_0_acid
            fi
            if [ $SERVER_0_MOO -eq 1 ]; then
                docker rm -f server_0_moo
            fi
            if [ $SERVER_0_SERVICES != "none" ]; then
                docker rm -f server_0_services
            fi
			docker rm -f server_0_db
			docker rm -f server_0_ircd
		elif [ $2 -gt 0 ]; then
			declare users="SERVER_${2}_USERS"
			if [ ${!users} -gt 0 ]; then
				docker rm -f server_${2}_users
			fi
			docker rm -f server_${2}_ircd
		fi
		echo "All containers of 'server $2' deleted."
	elif [ $1 = "all" ]; then
		for i in `seq 0 $[${NUMBER_OF_SERVERS}-1]`; do
			delete server $i
		done
		docker rm -v rizon_data
		rm -f data/volume_created
		echo "All servers deleted."
	else
		echo "Error: container '$name' does not exist."
	fi
}


# Example: list server 0
function list {
	if [ $# -eq 0 ]; then
		docker ps -a | grep -e "\bserver_[0-9]_\(ircd\|services\|acid\|moo\|db\|users\)\b"
	elif [ $1 = "server" ]; then
		if [ $2 -ge 0 ]; then
			docker ps -a | grep -e "\bserver_$2_\(ircd\|services\|acid\|moo\|db\|users\)\b"
		fi
	else
		echo "Error: incorrect command syntax."
	fi
}


source config.sh

case "$1" in
start)
	start $2 $3
	;;
stop)
	stop $2 $3
	;;
restart)
	restart $2 $3
	;;
build)
	build $2 $3
	;;
create)
	create $2 $3
	;;
delete)
	delete $2 $3
	;;
list)
	list $2 $3
	;;
*)
	echo "Error: Bad argument(s)."
	exit 65
	;;
esac

exit 0
