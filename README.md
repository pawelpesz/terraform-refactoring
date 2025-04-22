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

* [Non-static values in `moved` addresses](https://github.com/hashicorp/terraform/issues/31335)
* [Dynamic `moved` blocks](https://github.com/hashicorp/terraform/issues/33236)

## Examples

### Renaming resources
```hcl
moved {
  from = aws_s3_bucket.one
  to   = aws_s3_bucket.two
}
```

### Renaming module calls
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
  ...
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

```hcl
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

### Importing resources

```hcl
import {
  to = aws_instance.this
  id = "i-abcdef0123"
}

import {
  to = aws_s3_bucket.this
  id = "bucket-name"
}

import {
  to = aws_iam_policy.example
  id = "arn:aws:iam::123456789012:policy/example-policy"
}
```

Typically we would write the code for the imported resources by hand (as for new ones) but we can also have Terraform **generate the code** for us:

```
terraform plan -generate-config-out=imported-resources.tf
```

### Optionally importing resources

```hcl
import {
  for_each = var.import_flag ? [1] : []
  to       = aws_s3_bucket.this
  id       = "bucket-name"
}
```

The `import` block doesn't support count.

### Importing resources dynamically

```hcl
local {
  region_to_id_map = {
    eu-west-1    = "i-aaaaaaaaaa"
    us-east-1    = "i-bbbbbbbbbb"
    ca-central-1 = "i-cccccccccc"
  }
}

import {
  to = aws_instance.this
  id = local.region_to_id_map[var.aws_region]
}

resource "aws_instance" "this" {
  ...
}
```

```hcl
local {
  buckets = {
    one   = "bucket-one"
    two   = "bucket-two"
    three = "bucket-three"
  }
}

import {
  for_each = local.buckets
  to       = aws_s3_bucket.buckets[each.key]
  id       = each.value
}

resource "aws_s3_bucket" "buckets" {
  for_each = local.buckets
  ...
}
```

### Removing resources from state

```hcl
removed {
  from = aws_db_instance.mysql
  lifecycle {
    destroy = false
  }
}
```

No instance keys, such as `aws_db_instance.mysql[0]`, are allowed.

```
removed {
  from = aws_instance.this
  lifecycle {
    destroy = true
  }
  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Instance ${self.id} has been destroyed.'"
  }
}
```

### Combining various techniques

Real-world example where a [new version of the Datadog provider](https://github.com/DataDog/terraform-provider-datadog/releases/tag/v3.50.0) replaced several separate resources with a single one.

Old:
```hcl
resource "datadog_integration_aws" "this" {
  account_id = var.aws_account_id
  ...
}

resource "datadog_integration_aws_log_collection" "this" {
  account_id = var.aws_account_id
  ...
}
```

New:
```hcl
removed {
  from = datadog_integration_aws.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = datadog_integration_aws_log_collection.this
  lifecycle {
    destroy = false
  }
}

locals {
  integration_ids = {
    "1234567890" = "aaaabbbb-cccc-dddd-eeee-1234567890"
    "2345678901" = "11112222-3333-4444-5555-abcdef9876"
    ...
  }
}

import {
  for_each = var.aws_region == "eu-west-1" ? [1] : []
  to       = datadog_integration_aws_account.this
  id       = local.integration_ids[var.aws_account_id]
}

resource "datadog_integration_aws_account" "this" {
  aws_account_id = var.aws_account_id
  ...
  logs_config {
    lambda_forwarder {
      ...
    }
  }
}
```
