#!/usr/bin/env bash
#
# Shell functions run on the host machine, OUTSIDE the container.
#
# Usage:
#   soil/host-shim.sh <function name>

set -o nounset
set -o pipefail
set -o errexit

source soil/common.sh

live-image-tag() {
  ### image ID -> Docker tag name
  local image_id=$1

  case $image_id in
    (dummy)
      echo 'v-2022-08-29'
      ;;
    (clang|cpp|pea)
      # Updated with layer-py3
      echo 'v-2022-08-05'
      ;;
    (*)
      echo 'v-2022-08-04'
      ;;
  esac
}

make-soil-dir() {
  log-context 'make-soil-dir'

  mkdir --verbose -p _tmp/soil
  ls -l -d . _tmp _tmp/soil

  # Match what mount-perms does
  chmod --changes 777 _tmp _tmp/soil
  ls -l -d . _tmp _tmp/soil
}

show-disk-info() {
  # Debug 'no space left on device' issue
  echo 'DISKS'
  df -h
  echo

  # Useful but many permissions errors
  if false; then
    echo 'SPACE FOR IMAGES?'
    du --si -s ~/.local/share/ || true
    echo
  fi
}

podman-prune() {
  ### Should this work on Debian?

  if ! command -v podman; then
    echo 'no podman'
    return
  fi

  echo 'IMAGES'
  podman images --all
  echo

  if false; then
    # This causes an interactive prompt
    echo 'PRUNE'
    podman system prune || true
    echo

    show-disk-info

    echo 'PRUNE AS ROOT'
    sudo podman system prune || true
    echo

    show-disk-info
  fi
}

mount-perms() {
  ### Ensure that the guest can write to bind mount

  local repo_root=$1

  show-disk-info

  log-context 'mount-perms'

  # We have to chmod all dirs because 'build/py.sh all' creates
  # build/temp.linux-*, for example.  Also can't exclude .git/ because
  # submodules need it.
  time find "$repo_root" -type d -a -print \
    | xargs -d $'\n' -- chmod --changes 777 \
    | wc -l
  echo
}

job-reset() {
  ### Called betweenjobs

  show-disk-info

  log-context 'job-reset'

  # The VM runs as the 'build' user on sourcehut.  The podman container runs as
  # 'uke' user, which apparently gets UID 100999.
  #
  # Running as 'build', we can't remove files created by the guest, so use
  # 'sudo'.
  #
  # It's really these three dirs.
  # ls -l -d _tmp/soil _tmp/soil/logs _devbuild/bin || true

  sudo $0 mount-perms $PWD
  echo

  git status .
  echo

  # Similar to 'build/ovm-actions.sh clean', or 'build/native.sh clean', but also
  # does _tmp and _devbuild

  local -a dirs=(_tmp _bin _build _devbuild _test)
  #local -a dirs=(_tmp)

  log 'Removing temp dirs'
  log ''

  du --si -s "${dirs[@]}" || true
  rm -r -f "${dirs[@]}"
  echo

  show-disk-info
}

run-job-uke() {
  local docker=$1  # docker or podman
  local repo_root=$2
  local job_name=$3  # e.g. dev-minimal
  local debug_shell=${4:-}

  log-context 'run-job-uke'

  # Do this on the HOST because we write the pull time into it as well.  It's
  # shared between guest and host.
  make-soil-dir
  local soil_dir=$repo_root/_tmp/soil

  local -a flags=()

  local image_id
  case $job_name in
    (app-tests)
      # Hack to reuse this container, e.g. for 'build/py.sh all'
      image_id='ovm-tarball'
      # allocate pseudo TTY, otherwise fails on opening /dev/tty 
      flags=( -t )
      ;;
    (cpp-small|cpp-spec)
      image_id='cpp'
      ;;
    (cpp-coverage)
      image_id='clang'
      ;;
    (*)
      # docker.io is the namespace for hub.docker.com
      image_id=$job_name
      ;;
  esac

  local image="docker.io/oilshell/soil-$image_id"

  local tag=$(live-image-tag $image_id)

  local pull_status
  # Use external time command in POSIX format, so it's consistent between hosts
  set -o errexit
  command time -p -o $soil_dir/image-pull-time.txt \
    $docker pull $image:$tag
  pull_status=$?
  set +o errexit

  if test $pull_status -ne 0; then
    log "$docker pull failed with status $pull_status"

    # Save status for a check later
    mkdir -p _soil-jobs
    echo "$pull_status" > _soil-jobs/$job_name.status.txt

    # Return success
    return
  fi

  show-disk-info

  podman-prune

  local -a args
  if test -n "$debug_shell"; then
    # launch interactive shell
    flags+=( -i -t )

    # So we can run GDB
    # https://stackoverflow.com/questions/35860527/warning-error-disabling-address-space-randomization-operation-not-permitted
    flags+=( --cap-add SYS_PTRACE --security-opt seccomp=unconfined )

    # can mount other tools for debugging, like clang
    #local clang_dir=~/git/oilshell/oil_DEPS/clang+llvm-14.0.0-x86_64-linux-gnu-ubuntu-18.04
    #flags+=( --mount "type=bind,source=$clang_dir,target=/home/uke/oil_DEPS/$(basename $clang_dir)" )
    
    args=(bash)
  else
    args=(sh -c "cd /home/uke/oil; soil/worker.sh JOB-$job_name")
  fi

  $docker run "${flags[@]}" \
      --mount "type=bind,source=$repo_root,target=/home/uke/oil" \
      $image:$tag \
      "${args[@]}"
}

did-all-succeed() {
  ### Check if the given jobs succeeded

  local max_status=0
  for job_name in "$@"; do
    local status
    status=$(cat "_soil-jobs/$job_name.status.txt")

    echo "$job_name status: $status"
    if test $status -gt $max_status; then
      max_status=$status
    fi
  done

  log "Exiting with max status $max_status"

  return "$max_status"
}

local-test-uke() {
  ### Something I can run locally.  This is fast.

  # Simulate sourcehut with 'local-test-uke dummy dummy'
  local job_name=${1:-dummy}
  local job2=${2:-}

  local branch=$(git rev-parse --abbrev-ref HEAD)

  local fresh_clone=/tmp/soil-$job_name
  rm -r -f -v $fresh_clone

  local this_repo=$PWD
  git clone $this_repo $fresh_clone
  cd $fresh_clone
  git submodule update --init --recursive
  git checkout $branch

  sudo $0 mount-perms $fresh_clone
  sudo $0 run-job-uke docker $fresh_clone $job_name

  if test -n "$job2"; then
    $0 job-reset
    sudo $0 run-job-uke docker $fresh_clone $job2
  fi
}

local-shell() {
  local job_name=${1:-cpp}

  # Note: this currently requires local-test-uke first.  TODO: Remove that
  # restriction.

  local repo_root=/tmp/soil-$job_name
  # Run bash as debug shell
  sudo $0 run-job-uke docker $repo_root $job_name bash
}

cleanup() {
  sudo rm -r -f -v _tmp/soil /tmp/soil-*
}

"$@"
