resource "terraform_data" "deny_default_workspace" {
  lifecycle {
    precondition {
      condition     = terraform.workspace != "default"
      error_message = "Refusing to run in the default workspace. Create/select a workspace (e.g. 'prod') and re-run."
    }
  }
}
