# Terraform Refactoring

1. Moving resources in Terraform state without recreating them.
2. Importing existing resources into Terraform state.
3. Removing resources from Terraform state without actually destroying them.

https://developer.hashicorp.com/terraform/language/modules/develop/refactoring

## The old way

Terraform CLI commands:

```
terraform mv aws_security_group.one aws_security_group.two
terraform rm aws_security_group.three
```

## The new way

1. `moved` block (added in Terraform 1.1)
2. `import` block (1.5)
3. Expressions in the `import` `id` attribute (1.6)
4. Support for `for_each` in `import` (1.7)
5. `removed` block (1.7)

Still missing:

* Non-static values in `moved` addresses https://github.com/hashicorp/terraform/issues/31335
* Dynamic `moved` blocks https://github.com/hashicorp/terraform/issues/33236

## Examples

### Rename resources
```hcl
moved {
  from = aws_s3_bucket.one
  to   = aws_s3_bucket.two
}
```

### Rename modules
```hcl
moved {
  from = module.alpha
  to   = module.beta
}
```

### Adding count to resource

Old:
```hcl
resource "aws_s3_bucket" "one" {
  ...
}
```

New:
```hcl
resource "aws_s3_bucket" "one" {
  count = var.create_bucket ? 1 : 0
  ...
}
```

No explicit refactor needed ("Terraform automatically proposes to move the original object to instance zero"), although the official advice is to "write out the corresponding `moved` block".

```hcl
moved {
  from = aws_s3_bucket.one
  to   = aws_s3_bucket.one[0]
}
```

### Removing count from resource

No automatic move!

```hcl
moved {
  from = aws_s3_bucket.one[0]
  to   = aws_s3_bucket.one
}
```

### Converting from `count` to `for_each`

Old:
```hcl
resource "aws_s3_bucket" "buckets" {
  count = 3
  ...
}
```

New:
```hcl
resource "aws_s3_bucket" "buckets" {
  for_each = toset(["one", "two", "three"])
}
```

```hcl
moved {
  from = aws_s3_bucket.buckets[0]
  to   = aws_s3_bucket.buckets["one"]
}
moved {
  from = aws_s3_bucket.buckets[1]
  to   = aws_s3_bucket.buckets["two"]
}
moved {
  from = aws_s3_bucket.buckets[2]
  to   = aws_s3_bucket.buckets["three"]
}
```

### Moving between modules

```
moved {
  from = aws_s3_bucket.one
  to   = module.alpha.aws_s3_bucket.one
}
moved {
  from = module.alpha.aws_s3_bucket.one
  to   = aws_s3_bucket.one
}
moved {
  from = module.alpha.aws_s3_bucket.one
  to   = module.beta.aws_s3_bucket.one
}
```
