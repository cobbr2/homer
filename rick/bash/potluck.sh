potluck_generate_deploy_jar() {
  subproject="$1"
  rm -rf bazel-bin/"$subproject"
  bazel build //$subproject:docker.tar
  tar -C bazel-bin/"$subproject" -xf bazel-bin/"$subproject"/docker.tar
}

potluck_build_docker_image() {
  subproject="$1"
  ecr_repo="$2"

  build_args="-f bazel-bin/"$subproject"/Dockerfile"

  if [ -n "${ecr_repo}" ] ; then
    build_args="${build_args} -t ${ecr_repo}:latest"
  fi
  docker build ${build_args} bazel-bin/"$subproject"
}
