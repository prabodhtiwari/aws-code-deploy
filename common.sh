#!/bin/bash

# Begin Standard 'imports'
set -e
set -o pipefail


gray="\\e[37m"
blue="\\e[36m"
red="\\e[31m"
green="\\e[32m"
reset="\\e[0m"

#######################################
# echoes a message in blue
# Globals:
#   None
# Arguments:
#   Message
# Returns:
#   None
#######################################
info() { echo -e "${blue}INFO: $*${reset}"; }

#######################################
# echoes a message in red
# Globals:
#   None
# Arguments:
#   Message
# Returns:
#   None
#######################################
error() { echo -e "${red}ERROR: $*${reset}"; }

#######################################
# echoes a message in grey. Only if debug mode is enabled
# Globals:
#   DEBUG
# Arguments:
#   Message
# Returns:
#   None
#######################################
debug() {
  if [[ "${DEBUG}" == "true" ]]; then
    echo -e "${gray}DEBUG: $*${reset}";
  fi
}

#######################################
# echoes a message in green
# Globals:
#   None
# Arguments:
#   Message
# Returns:
#   None
#######################################
success() { echo -e "${green}âœ” $*${reset}"; }

#######################################
# echoes a message in red and terminates the programm
# Globals:
#   None
# Arguments:
#   Message
# Returns:
#   None
#######################################
fail() { echo -e "${red}âœ– $*${reset}"; exit 1; }

## Enable debug mode.
enable_debug() {
  if [[ "${DEBUG}" == "true" ]]; then
    info "Enabling debug mode."
    set -x
  fi
}

#######################################
# echoes a message in blue
# Globals:
#   status: Exit status of the command that was executed.
#   output_file: Local path with captured output generated from the command.
# Arguments:
#   command: command to run
# Returns:
#   None
#######################################
run() {
  output_file="/var/tmp/pipe-$(date +%s)-$RANDOM"

  echo "$@"
  set +e
  "$@" | tee "$output_file"
  status=$?
  set -e
}

# End standard 'imports'
