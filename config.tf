data "template_file" "script" {
    template = "${file("${path.module}/template/ssh_config.rb")}"

    vars {
        region = "${var.s3-region}"
        bucket_name = "${var.bucket_name}"
        env_name = "${terraform.workspace}"
        filename = "${var.filename}"
    }
}
resource "null_resource" "ssh_trigger" {
    triggers {
        node_list = "${var.node_list}"
    }

    provisioner "local-exec" {
        command = "${format("cat <<\"EOF\" > \"%s\"\n%s\nEOF", "${path.root}/keys/ssh_config_${var.project}-${terraform.workspace}.rb", data.template_file.script.rendered)}"
    }
}

