# Inkwell Print Co. — the orders service may READ exactly one secret.
path "secret/data/inkwell/orders" {
  capabilities = ["read"]
}
