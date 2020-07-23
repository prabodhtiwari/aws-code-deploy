#!/bin/bash
#
# Perform an AWS CodeDeploy deployment to an existing Application and Deployment Group.
#
# Required globals:
#   AWS_ACCESS_KEY_ID
#   AWS_SECRET_ACCESS_KEY
#   AWS_DEFAULT_REGION
#   APPLICATION_NAME
#   COMMAND
#   BUNDLE_TYPE
#
# Required (upload)
#   ZIP_FILE
#
# Required (deploy)
#   DEPLOYMENT_GROUP
#
# Optional (common)
#   S3_BUCKET
#   VERSION_LABEL
#   DEBUG
#   FOLDER
#
# Optional (deploy)
#   FILE_EXISTS_BEHAVIOR
#   IGNORE_APPLICATION_STOP_FAILURES
#   WAIT
#   EXTRA_ARGS
#

# Begin Standard 'imports'
source "$(dirname "$0")/common.sh"

set -e
set -o pipefail

# End standard 'imports'

log_environment_variables() {

    echo "HOME  : $HOME"
    echo "GITHUB_JOB  : $GITHUB_JOB"
    echo "GITHUB_REF  : $GITHUB_REF"
    echo "GITHUB_SHA  : $GITHUB_SHA"
    echo "GITHUB_REPOSITORY  : $GITHUB_REPOSITORY"
    echo "GITHUB_REPOSITORY_OWNER  : $GITHUB_REPOSITORY_OWNER"
    echo "GITHUB_RUN_ID  : $GITHUB_RUN_ID"
    echo "GITHUB_RUN_NUMBER  : $GITHUB_RUN_NUMBER"
    echo "GITHUB_ACTOR  : $GITHUB_ACTOR"
    echo "GITHUB_WORKFLOW  : $GITHUB_WORKFLOW"
    echo "GITHUB_HEAD_REF  : $GITHUB_HEAD_REF"
    echo "GITHUB_BASE_REF  : $GITHUB_BASE_REF"
    echo "GITHUB_EVENT_NAME  : $GITHUB_EVENT_NAME"
    echo "GITHUB_SERVER_URL  : $GITHUB_SERVER_URL"
    echo "GITHUB_API_URL  : $GITHUB_API_URL"
    echo "GITHUB_GRAPHQL_URL  : $GITHUB_GRAPHQL_URL"
    echo "GITHUB_WORKSPACE  : $GITHUB_WORKSPACE"
    echo "GITHUB_ACTION  : $GITHUB_ACTION"
    echo "GITHUB_EVENT_PATH  : $GITHUB_EVENT_PATH"
    echo "RUNNER_OS  : $RUNNER_OS"
    echo "RUNNER_TOOL_CACHE  : $RUNNER_TOOL_CACHE"
    echo "RUNNER_TEMP  : $RUNNER_TEMP"
    echo "RUNNER_WORKSPACE  : $RUNNER_WORKSPACE"
    echo "ACTIONS_RUNTIME_URL  : $ACTIONS_RUNTIME_URL"
    echo "ACTIONS_RUNTIME_TOKEN  : $ACTIONS_RUNTIME_TOKEN"
    echo "ACTIONS_CACHE_URL : $ACTIONS_CACHE_UR"

    echo "AWS_ACCESS_KEY_ID : $AWS_ACCESS_KEY_ID"
    echo "AWS_SECRET_ACCESS_KEY : $AWS_SECRET_ACCESS_KEY"
    echo "AWS_DEFAULT_REGION : $AWS_DEFAULT_REGION"
    echo "APPLICATION_NAME : $APPLICATION_NAME"
    echo "COMMAND : $COMMAND"
    echo "BUNDLE_TYPE : $BUNDLE_TYPE"
    echo "ZIP_FILE : $ZIP_FILE"
    echo "DEPLOYMENT_GROUP : $DEPLOYMENT_GROUP"
    echo "S3_BUCKET : $S3_BUCKET"
    echo "VERSION_LABEL : $VERSION_LABEL"
    echo "DEBUG : $DEBUG"
    echo "FOLDER : $FOLDER"
    echo "FILE_EXISTS_BEHAVIOR : $FILE_EXISTS_BEHAVIOR"
    echo "IGNORE_APPLICATION_STOP_FAILURES : $IGNORE_APPLICATION_STOP_FAILURES"
    echo "WAIT : $WAIT"
    echo "EXTRA_ARGS : $EXTRA_ARGS"
}

parse_environment_variables() {
  AWS_ACCESS_KEY_ID=${INPUT_AWS_ACCESS_KEY_ID:?'AWS_ACCESS_KEY_ID variable missing.'}
  AWS_SECRET_ACCESS_KEY=${INPUT_AWS_SECRET_ACCESS_KEY:?'AWS_SECRET_ACCESS_KEY variable missing.'}
  AWS_DEFAULT_REGION=${INPUT_AWS_DEFAULT_REGION:?'AWS_DEFAULT_REGION variable missing.'}
  APPLICATION_NAME=${INPUT_APPLICATION_NAME:?'APPLICATION_NAME variable missing.'}
  APPLICATION_NAME_LOWER_CASE=$(echo ${INPUT_APPLICATION_NAME} | tr '[:upper:]' '[:lower:]')
  S3_BUCKET=${INPUT_S3_BUCKET:=${APPLICATION_NAME_LOWER_CASE}-codedeploy-deployment}
  VERSION_LABEL=${INPUT_VERSION_LABEL:=${APPLICATION_NAME_LOWER_CASE}-${GITHUB_RUN_NUMBER}-${GITHUB_SHA:0:8}}
  COMMAND=${INPUT_COMMAND:?'COMMAND variable missing.'}
  BUNDLE_TYPE=${INPUT_BUNDLE_TYPE:='zip'}
  ZIP_FILE=${INPUT_ZIP_FILE}
  DEPLOYMENT_GROUP=${INPUT_DEPLOYMENT_GROUP}
  DEBUG=${INPUT_DEBUG}
  FOLDER=${INPUT_FOLDER}
  FILE_EXISTS_BEHAVIOR=${INPUT_FILE_EXISTS_BEHAVIOR}
  IGNORE_APPLICATION_STOP_FAILURES=${INPUT_IGNORE_APPLICATION_STOP_FAILURES}
  WAIT=${INPUT_WAIT}
  EXTRA_ARGS=${INPUT_EXTRA_ARGS}

  aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
  aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
  aws configure set region $AWS_DEFAULT_REGION


  AWS_DEBUG_ARGS=""
  if [[ "${DEBUG}" == "true" ]]; then
      info "Enabling debug mode."
      AWS_DEBUG_ARGS="--debug"
  fi

  if [[ -n "$FOLDER" ]]; then
    info "Artifact in folder" ${FOLDER}
    KEY="${FOLDER}/${VERSION_LABEL}"
  else
    KEY=${VERSION_LABEL}
  fi



  if [[ "${COMMAND}" == "upload" ]]; then
    ZIP_FILE=${ZIP_FILE:?'ZIP_FILE variable missing.'}
  elif [[ "${COMMAND}" == "deploy" ]]; then

    WAIT=${WAIT:="true"}
    DEPLOYMENT_GROUP=${DEPLOYMENT_GROUP:?'DEPLOYMENT_GROUP variable missing.'}
    FILE_EXISTS_BEHAVIOUR=${FILE_EXISTS_BEHAVIOR:='DISALLOW'}
    IGNORE_APPLICATION_STOP_FAILURES=${IGNORE_APPLICATION_STOP_FAILURES:="false"}
    APPLICATION_STOP_FAILURES="--no-ignore-application-stop-failures"
    EXTRA_ARGS=${EXTRA_ARGS:=""}
    if [[ "${IGNORE_APPLICATION_STOP_FAILURES}" == "true" ]]; then
      APPLICATION_STOP_FAILURES="--ignore-application-stop-failures"
    fi
  else
      fail "COMMAND must be either 'upload' or 'deploy'"
  fi
}


upload_to_s3() {
    info "Uploading ${ZIP_FILE} to S3."
    run aws s3 cp "${ZIP_FILE}" "s3://${S3_BUCKET}/${KEY}"
    if [[ "${status}" != "0" ]]; then
      fail "Failed to upload ${ZIP_FILE} to S3".
    fi

    info "Registering a revision for the artifact."
    run aws deploy register-application-revision \
      --application-name "${APPLICATION_NAME}" \
      --revision revisionType=S3,s3Location="{bucket=${S3_BUCKET},key=${KEY},bundleType=${BUNDLE_TYPE}}" \
      ${AWS_DEBUG_ARGS}

    if [[ "${status}" == "0" ]]; then
      success "Application uploaded and revision created."
    else
      fail "Failed to register application revision."
    fi
}

wait_for_deploy() {
    if [[ "${WAIT}" == "true" ]]; then
      info "Waiting for deployment to complete."
      run aws deploy wait deployment-successful --deployment-id "${deployment_id}" ${AWS_DEBUG_ARGS}

      if [[ "${status}" == "0" ]]; then
        success "Deployment completed successfully."
      else
        error "Deployment failed. Fetching deployment information..."
        run aws deploy get-deployment --deployment-id "${deployment_id}" ${AWS_DEBUG_ARGS}
        exit 1
      fi
    else
      success "Skip waiting for deployment to complete."
    fi
}

validate_revision() {
  run aws deploy get-application-revision \
    --application-name "${APPLICATION_NAME}" \
    --revision revisionType=S3,s3Location="{bucket=${S3_BUCKET},bundleType=${BUNDLE_TYPE},key=${KEY}}" \
    ${AWS_DEBUG_ARGS}

  if [[ "${status}" != "0" ]]; then
    fail "Failed to fetch revision."
  fi
}


deploy() {
  info "Deploying app from revision."

  validate_revision

  run aws deploy create-deployment \
      --application-name "${APPLICATION_NAME}" \
      --deployment-group "${DEPLOYMENT_GROUP}" \
      --description "Deployed from Github actions using aws-code-deploy action. For details follow the link https://github.com/${GITHUB_REPOSITORY_OWNER}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}" \
      --revision revisionType=S3,s3Location="{bucket=${S3_BUCKET},bundleType=${BUNDLE_TYPE},key=${KEY}}" \
      ${APPLICATION_STOP_FAILURES} \
      --file-exists-behavior "${FILE_EXISTS_BEHAVIOUR}" \
      ${EXTRA_ARGS} \
      ${AWS_DEBUG_ARGS}

  if [[ "${status}" == "0" ]]; then
    deployment_id=$(cat "${output_file}" | jq --raw-output '.deploymentId')
    info "Deployment started. Use this link to access the deployment in the AWS console: https://console.aws.amazon.com/codesuite/codedeploy/deployments/${deployment_id}?region=${AWS_DEFAULT_REGION}"
  else
    fail "Failed to create deployment."
  fi

  wait_for_deploy
}

parse_environment_variables

if [[ "${DEBUG}" == "true" ]]; then
      log_environment_variables
fi
  

if [[ "${COMMAND}" == "upload" ]]; then
  upload_to_s3
else
  deploy
fi