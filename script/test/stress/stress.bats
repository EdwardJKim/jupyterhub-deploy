#!/usr/bin/env bats

load ../integration/helpers

NODES=3
CONTAINERS=5
MEM_PER_CONTAINER="512m"
MEM_PLUS_SWAP=-1

function teardown() {
	swarm_manage_cleanup
	stop_docker
}

# Start N containers on the cluster in parallel
function start_containers {
	local n="$1"
	local pids
	# Run `docker run` in parallel...
	for ((i=0; i < $n; i++)); do
		docker --tls -H 127.0.0.1:2376 run -d \
			--name jupyter-test-$i \
			--env JPY_API_TOKEN="12345" \
			--memory=$MEM_PER_CONTAINER --memory-swap=$MEM_PLUS_SWAP \
			-v /media/nfs/data:/home/data_scientist/data \
	                edwardjkim/singleuser &
		pids[$i]=$!
	done
}

# Waits for all containers to exit (not running) for up to $1 seconds.
function wait_containers_load {
	local attempts=0
	local max_attempts=$1
	until [ $attempts -ge $max_attempts ]; do
		run docker --tls -H 127.0.0.1:2376 ps -q
		[[ "$status" -eq 0 ]]
		num_lines=`docker --tls -H 127.0.0.1:2376 ps | grep jupyter-test | wc -l`
		if [ "$num_lines" -eq $CONTAINERS ] ; then
			break
		fi
		echo "Containers still running: $output" >&2
		sleep 1
	done
	[[ $attempts -lt $max_attempts ]]
}

function copy_ipynb {
	local n="$1"
	# Run `docker exec` in parallel...
	for ((i=0; i < $n; i++)); do
		tar -cf - test/stress/test_pandas.ipynb | \
			docker --tls -H 127.0.0.1:2376 exec -i jupyter-test-$i /bin/tar -C /tmp -xf -
	done
}

function copy_data {
	local n="$1"
	# Run `docker exec` in parallel...
	for ((i=0; i < $n; i++)); do
		tar -cf - test/stress/2001.csv | \
			docker --tls -H 127.0.0.1:2376 exec -i jupyter-test-$i /bin/tar -C /tmp -xf -
	done
}

function run_ipynb {
	local n="$1"
	# Run `docker exec` in parallel...
	for ((i=0; i < $n; i++)); do
		docker --tls -H 127.0.0.1:2376 exec -i jupyter-test-$i \
			ipython3 nbconvert --to=markdown --ExecutePreprocessor.enabled=True \
			/tmp/test/stress/test_pandas.ipynb &
	done
}

@test "spawning $CONTAINERS containers on $NODES nodes" {
	
	# Verify that Swarm can see all the nodes.
	run docker --tls -H 127.0.0.1:2376 info
	[ "$status" -eq 0 ]
	output="${output//$'\r'}"
	[[ "$output" =~ "Nodes: $NODES" ]]

	# Start the containers (random sleeps).
	start_containers $CONTAINERS

	wait_containers_load 10
	
	# Make sure all containers were scheduled.
	#run docker --tls -H 127.0.0.1:2376 ps -qa
	#[ "$status" -eq 0 ]
	#[ "${#lines[@]}" -eq $CONTAINERS ]
}

@test "copying notebooks" {

	copy_ipynb $CONTAINERS

	wait_containers_load 20
}

#@test "copying data files" {
#	copy_data $CONTAINERS
#
#	wait_containers_load 20
#}

@test "making sure that the load was spread evenly (spread strategy)" {
	# Make sure every node was utilized and the load was spread evenly (we are
	# using the spread strategy).
	run docker --tls -H 127.0.0.1:2376 info
	# containers_per_node is the number of containers we should see on every
	# node. For instance, if we scheduled 10 containers on 2 nodes, then we
	# should have 5 containers per node.
	local containers_per_node=$(( $CONTAINERS / $NODES ))
	# Check how many nodes have the expected "containers_per_node" containers
	# count. It should equal to the total number of nodes.
	num_nodes=`echo $output | grep -o -e "Containers: ${containers_per_node} " | wc -l`
	[ "$num_nodes" -eq "$NODES" ]
}

@test "running test_pandas.ipynb" {

	run run_ipynb $CONTAINERS
	[ "$status" -eq 0 ]
	echo "$output"
}
	
#@test "cleaning up" {
#
#	docker --tls -H 127.0.0.1:2376 ps -qa | xargs docker --tls -H 127.0.0.1:2376 rm -f
#	run docker --tls -H 127.0.0.1:2376 ps -qa
#	[ "${#lines[@]}" -eq 0 ]
#}
