#!/bin/bash
set -ex

# Harbor E2E 测试脚本
# 用法: ./run-harbor-e2e.sh [HARBOR_HOST_SCHEMA] [HARBOR_HOST] [HARBOR_PASSWORD] [DOCKER_OPTS]

#
# 例如:
# 1. 基本用法: ./run-harbor-e2e.sh http 127.0.0.1  Harbor12345
# 2. 附加 Docker 选项: ./run-harbor-e2e.sh http 127.0.0.1 Harbor12345 test --network host

if [ "${RUN_E2E_TEST}" != "true" ]; then
    echo "Skipping Harbor e2e test"
    exit 0
fi

TEST_IMAGE=registry.alauda.cn:60070/fundamentals/harbor-e2e-engine:5.3.0-api

HARBOR_HOST_SCHEMA=${1:-"http"}
HARBOR_HOST=${2:-"127.0.0.1"}
HARBOR_PASSWORD=${3:-"Harbor12345"}
INSTANCE_NAME=${4:-"harbor"}

DOCKER_OPTS=""
if [ $# -ge 4 ]; then
    shift 4
    DOCKER_OPTS="$@"
fi

if [ -z "$RESULT_DIR" ]; then
   RESULT_DIR="./results"
fi

OUTPUT_DIR="$RESULT_DIR/$INSTANCE_NAME"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(realpath "${OUTPUT_DIR}")


EXCLUDE_TAGS_ARRAY=()
case "${TEST_SUITE}" in
    "daily")
        EXCLUDE_TAGS_ARRAY=("proxy_cache" "gc" "replic_rule" "referrers" "retain_image_last_pull_time" "robot_account" "scan_all" "job_service_dashboard" "security_hub" "tag_immutability" "tag_retention")
        ;;
    "full")
        EXCLUDE_TAGS_ARRAY=("proxy_cache")
        ;;
    "custom")
        if [ -n "${EXCLUDE_TAGS}" ]; then
            read -ra EXCLUDE_TAGS_ARRAY <<< "${EXCLUDE_TAGS}"
        else
            EXCLUDE_TAGS_ARRAY=("proxy_cache" "replic_rule")
        fi
        ;;
    *)
        echo "Using daily suite as default"
        EXCLUDE_TAGS_ARRAY=("proxy_cache" "replic_rule")
        ;;
esac

EXCLUDE_TAGS=""
if [ ${#EXCLUDE_TAGS_ARRAY[@]} -gt 0 ]; then
    EXCLUDE_TAGS=$(printf "%sOR" "${EXCLUDE_TAGS_ARRAY[@]}" | sed 's/OR$//')
fi

echo "Run Harbor e2e..."
echo "Harbor password: ${HARBOR_PASSWORD}"
echo "Harbor host: ${HARBOR_HOST}"
echo "Harbor scheme: ${HARBOR_HOST_SCHEMA}"
echo "Docker options: ${DOCKER_OPTS}"
echo "Exclude tags: ${EXCLUDE_TAGS}"
echo "Output ${OUTPUT_DIR}"

docker run ${DOCKER_OPTS} -i --privileged \
  -e HARBOR_PASSWORD="${HARBOR_PASSWORD}" \
  -e HARBOR_HOST_SCHEMA="${HARBOR_HOST_SCHEMA}" \
  -e HARBOR_HOST="${HARBOR_HOST}" \
  -e COSIGN_EXPERIMENTAL=1 \
  -e CONTAINERD_ADDRESS=/var/run/docker/containerd/containerd.sock \
  -v /var/log/harbor/:/var/log/harbor/ \
  -v "${OUTPUT_DIR}:/results" \
  -w /drone \
  "${TEST_IMAGE}" \
  robot --exclude "${EXCLUDE_TAGS}" \
  -v ip:"${HARBOR_HOST}" -v ip1: \
  -v http_get_ca:false \
  -v protocol:"${HARBOR_HOST_SCHEMA}" \
  -v HARBOR_PASSWORD:"${HARBOR_PASSWORD}" \
  -v DOCKER_USER:"${DOCKER_USER}" \
  -v DOCKER_PWD:"${DOCKER_PWD}" \
  -d /results \
  /drone/tests/robot-cases/Group1-Nightly/Setup.robot \
  /drone/tests/robot-cases/Group0-BAT/API_DB_SUCCESS.robot

if [ $? -eq 0 ]; then
    echo "Harbor e2e done: passed";
    exit 0
else
    echo "Harbor e2e done: failed";
    exit 1
fi
