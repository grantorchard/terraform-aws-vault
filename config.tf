data template_file "userdata" {
  template = file("${path.module}/templates/userdata.yaml")

  vars = {
    vault_conf       = base64encode(templatefile("${path.module}/templates/vault.conf",
      {
        node_id      = var.hostname
        leader_ip    = "${var.hostname}.${data.aws_route53_zone.this.name}"
        kms_key_id   = aws_kms_key.this.id
      }
    ))
  }
}