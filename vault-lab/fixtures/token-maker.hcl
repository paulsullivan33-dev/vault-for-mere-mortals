# May create child tokens (children may hold only a subset of the parent's policies).
path "auth/token/create" {
  capabilities = ["update"]
}
