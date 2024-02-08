resource "boundary_scope" "project" {
  name     = var.scope_name
  scope_id = var.parent_scope_id
}

resource "boundary_role" "this" {
  name          = "${var.scope_name}_project_admin"
  principal_ids = var.project_admin_principal_ids
  grant_strings = [
    "ids=*;type=*;actions=*"
  ]
  scope_id      = boundary_scope.project.scope_id
  grant_scope_id = boundary_scope.project.id
}

resource "vault_token" "this" {
  period = 7200
  renewable = true
  no_parent = true
  policies = [
    "default",
    "sign_ssh_certificate",
    "revoke_lease"
  ]
  lifecycle {
    ignore_changes = all 
  }
}

resource "boundary_credential_store_vault" "this" {
  depends_on  = [ 
    boundary_role.this 
  ]
  name        = "HCP Vault"
  address     = var.vault_address
  token       = vault_token.this.client_token
  namespace   = "admin/tfo-apj-demos"
  scope_id    = boundary_scope.project.id
}

resource "boundary_credential_library_vault_ssh_certificate" "this" {
  depends_on = [ 
    boundary_role.this 
  ]
  name = "SSH Key Signing"
  path = "ssh/sign/boundary"
  username = "ubuntu" #"{{.User.Name}}"
  key_type            = "ed25519"
  credential_store_id = boundary_credential_store_vault.this.id
  extensions = {
    permit-pty = ""
  }
}

resource "boundary_credential_library_vault" "ldap_creds" {
  count               = var.ldap_credential_library ? 1 : 0
  name                = "ldap_creds"
  description         = "Dynamic LDAP credentials"
  credential_store_id = boundary_credential_store_vault.foo.id
  path                = "ldap/creds/vault_ldap_dynamic_demo_role"
  http_method         = "GET"
}
