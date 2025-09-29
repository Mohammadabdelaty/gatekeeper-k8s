package k8spolicy

__allowed_registry__ = "harbor.local"

violation[{"msg": msg, "details":{}}]  {
  input.review.kind.kind == "Job"
  container := input.review.object.spec.template.spec.containers[_]
  not startswith(container.image, __allowed_registry__)
  msg := sprintf("Container %q uses disallowed image: %q", [container.name, container.image])
}

violation[{"msg": msg, "details":{}}]  {
  input.review.kind.kind == "Job"
  container := input.review.object.spec.template.spec.containers[_]
  not container.securityContext.runAsNonRoot
  msg := "Job must not run as root"
}

violation[{"msg": msg, "details":{}}]  {
  input.review.kind.kind == "Job"
  container := input.review.object.spec.template.spec.containers[_]
  not container.securityContext.runAsUser
  msg := "Container must set runAsUser"
}

violation[{"msg": msg, "details":{}}]  {
  input.review.kind.kind == "Job"
  container := input.review.object.spec.template.spec.containers[_]
  not container.securityContext.runAsGroup
  msg := "Container must set runAsGroup"
}

violation[{"msg": msg, "details":{}}]  {
  input.review.kind.kind == "Job"
  not input.review.object.spec.template.spec.securityContext.fsGroup
  msg := "Pod must set fsGroup"
}