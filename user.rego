package main

__allowed_registry__ = "harbor.local"

deny[msg]  {
  input.kind == "Job"
  container := input.spec.template.spec.containers[_]
  not startswith(container.image, __allowed_registry__)
  msg := sprintf("Container %q uses disallowed image: %q", [container.name, container.image])
}

deny[msg]  {
  input.kind == "Job"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.runAsNonRoot
  msg := "Job must not run as root"
}

deny[msg]  {
  input.kind == "Job"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.runAsUser
  msg := "Container must set runAsUser"
}

deny[msg]  {
  input.kind == "Job"
  container := input.spec.template.spec.containers[_]
  not container.securityContext.runAsGroup
  msg := "Container must set runAsGroup"
}

deny[msg]  {
  input.kind == "Job"
  not input.spec.template.spec.securityContext.fsGroup
  msg := "Pod must set fsGroup"
}
