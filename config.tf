data "template_file" "script" {
    template = "${file("${path.module}/template/ssh_config.rb")}"

    vars {
        region = "${var.region}"
        bucket_name = "${var.bucket_name}"
        env_name = "${terraform.env}"
        filename = "${var.filename}"
    }
}
resource "null_resource" "ssh_trigger" {
    triggers {
        node_list = "${var.node_list}"
    }

    provisioner "local-exec" {
        command = "echo <<EOF > ssh_config.rb
${data.template_file.script.rendered}
EOF
&& ./ssh_config.rb"
    }
}

