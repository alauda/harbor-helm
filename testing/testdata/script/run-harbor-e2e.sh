#!/bin/bash

# Harbor E2E 测试脚本
# 用法: ./run-harbor-e2e.sh [HARBOR_HOST_SCHEMA] [HARBOR_HOST] [HARBOR_PASSWORD] [DOCKER_OPTS]

#
# 例如:
# 1. 基本用法: ./run-harbor-e2e.sh http 127.0.0.1  Harbor12345
# 2. 附加 Docker 选项: ./run-harbor-e2e.sh http 127.0.0.1 Harbor12345 --network host

if [ "${RUN_E2E_TEST}" != "true" ]; then
    echo "Skipping Harbor e2e test"
    exit 0
fi

TEST_IMAGE=registry.alauda.cn:60080/fundamentals/harbor-e2e-engine:5.3.0-api


echo "$@"
HARBOR_HOST_SCHEMA=${1:-"http"}
HARBOR_HOST=${2:-"127.0.0.1"}
HARBOR_PASSWORD=${3:-"Harbor12345"}

shift 3
DOCKER_OPTS="$@"

EXCLUDE_TAGS="proxy_cacheORreplic_rule"

echo "Run Harbor e2e..."
echo "Harbor password: ${HARBOR_PASSWORD}"
echo "Harbor host: ${HARBOR_HOST}"
echo "Harbor scheme: ${HARBOR_HOST_SCHEMA}"
echo "Docker options: ${DOCKER_OPTS}"
echo "Exclude tags: ${EXCLUDE_TAGS}"

docker run ${DOCKER_OPTS} -i --privileged \
  -e HARBOR_PASSWORD="${HARBOR_PASSWORD}" \
  -e HARBOR_HOST_SCHEMA="${HARBOR_HOST_SCHEMA}" \
  -e HARBOR_HOST="${HARBOR_HOST}" \
  -e COSIGN_EXPERIMENTAL=1 \
  -e CONTAINERD_ADDRESS=/var/run/docker/containerd/containerd.sock \
  -v /var/log/harbor/:/var/log/harbor/ \
  -w /drone \
  "${TEST_IMAGE}" \
  robot --exclude "${EXCLUDE_TAGS}" \
  -v ip:"${HARBOR_HOST}" -v ip1: \
  -v http_get_ca:false \
  -v protocol:"${HARBOR_HOST_SCHEMA}" \
  -v HARBOR_PASSWORD:"${HARBOR_PASSWORD}" \
  -v DOCKER_USER:"${DOCKER_USER}" \
  -v DOCKER_PWD:"${DOCKER_PWD}" \
  /drone/tests/robot-cases/Group1-Nightly/Setup.robot \
  /drone/tests/robot-cases/Group0-BAT/API_DB_SUCCESS.robot

if [ $? -eq 0 ]; then
    echo "Harbor e2e done: passed";
    exit 0
else
    echo "Harbor e2e done: failed";
    exit 1
fi