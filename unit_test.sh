#!/bin/bash

# DOCKER_CONF env var set by bootstrap.sh ...

cd $APP_ROOT

function teardown_container {
    docker rm -f $TEST_CONTAINER_ID || true
}

trap "teardown_container" EXIT SIGINT SIGTERM

# Do tests
TEST_CONTAINER_ID=$(docker run -d \
    -v $(pwd):/cdapp \
    -e ACG_CONFIG="/cdapp/cdappconfig.json" \
    $IMAGE:$IMAGE_TAG \
    /bin/bash -c 'sleep infinity' || echo "0")

if [[ "$TEST_CONTAINER_ID" ==  "0" ]]; then
    echo "Failed to start test container"
    exit 1
fi

ARTIFACTS_DIR="$WORKSPACE/artifacts"
mkdir -p $ARTIFACTS_DIR

# Run tests
echo '=============================='
echo '====   Running Go Tests   ===='
echo '=============================='
set +e
docker exec $TEST_CONTAINER_ID /bin/bash -c 'go test -v race -coverprofile=coverage.txt -covermode=atomic ./...'
TEST_RESULT=$?
set -e
# Copy test reports
docker cp $TEST_CONTAINER_ID:/coverage.txt $ARTIFACTS_DIR/junit-coverage.txt
if [ $TEST_RESULT -ne 0 ]; then
	echo '====================================='
	echo '====   ✖ ERROR: GO TEST FAILED  ===='
	echo '====================================='
	exit 1
fi

echo '====================================='
echo '====   ✔ SUCCESS: PASSED TESTS   ===='
echo '====================================='

teardown_container

