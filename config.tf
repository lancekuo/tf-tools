data "template_file" "script_s3" {
    count = "${var.enable_s3_backend}"
    template = "${file("${path.module}/template/ssh_config_s3.rb")}"

    vars {
        region = "${var.s3-region}"
        bucket_name = "${var.bucket_name}"
        env_name = "${terraform.workspace}"
        filename = "${var.filename}"
    }
}
data "template_file" "script" {
    count = "${1-var.enable_s3_backend}"
    template = "${file("${path.module}/template/ssh_config.rb")}"

    vars {
        env_name = "${terraform.workspace}"
        filename = "${var.filename}"
    }
}
resource "null_resource" "ssh_trigger_s3" {
    count = "${var.enable_s3_backend}"
    triggers {
        node_list = "${var.node_list}"
    }

    provisioner "local-exec" {
        command = "${format("cat <<\"EOF\" > \"%s\"\n%s\nEOF", "${path.root}/keys/ssh_config_${var.project}-${terraform.workspace}.rb", data.template_file.script_s3.rendered)}"
    }
}

resource "null_resource" "ssh_trigger" {
    count = "${1-var.enable_s3_backend}"
    triggers {
        node_list = "${var.node_list}"
    }

    provisioner "local-exec" {
        command = "${format("cat <<\"EOF\" > \"%s\"\n%s\nEOF", "${path.root}/keys/ssh_config_${var.project}-${terraform.workspace}.rb", data.template_file.script.rendered)}"
    }
}

