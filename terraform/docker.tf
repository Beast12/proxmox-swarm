resource "docker_network" "stack_networks" {
  for_each = toset(var.docker_networks)

  name       = each.value
  driver     = "overlay"
  attachable = true
}
