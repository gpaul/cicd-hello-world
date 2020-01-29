resource "src-git": {
  type: "git"
  param url: "$(context.git.url)"
  param revision: "$(context.git.commit)"
}

resource "gitops-git": {
  type: "git"
  param url: "https://github.com/gpaul/cicd-hello-world-gitops-private"
  param revision: "master"
}

resource "docker-image": {
  type: "image"
  param url: "gpaul/hello-world:$(context.build.name)"
  param digest: "$(inputs.resources.docker-image.digest)"
}

task "test": {
  inputs: ["src-git"]

  steps: [
    {
      name: "test"
      image: "golang:1.13.0-buster"
      command: [ "go", "test", "./..." ]
      workingDir: "/workspace/src-git"
    }
  ]
}

task "build": {
  inputs: ["src-git"]
  outputs: ["docker-image"]
  deps: ["test"]

  steps: [
    {
      name: "build-and-push"
      image: "chhsiao/kaniko-executor"
      args: [
        "--destination=$(outputs.resources.docker-image.url)",
        "--context=/workspace/src-git",
        "--oci-layout-path=/workspace/output/docker-image",
        "--dockerfile=/workspace/src-git/Dockerfile"
      ]
    }
  ]
}

task "deploy": {
  inputs: ["docker-image", "gitops-git"]
  steps: [
    {
      name: "update-gitops-repo"
      image: "mesosphere/update-gitops-repo:master"
      workingDir: "/workspace/gitops-git"
      args: [
        "-verbose",
        "-git-revision=$(context.git.commit)",
        "-force-push",
        "-substitute=imageName=gpaul/hello-world@$(inputs.resources.docker-image.digest)"
      ]
    }
  ]
}

actions: [
  {
    tasks: ["build", "deploy"]
    on push branches: ["master"]
  },
  {
    tasks: ["build"]
    on pull_request chatops: ["build"]
  },
  {
    tasks: ["build"]
    on push tags: ["*"]
  }
]
