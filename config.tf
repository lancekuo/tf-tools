data "template_file" "script_s3" {
    count = "${var.enableS3Backend}"
    template = "${file("${path.module}/template/ssh_config_s3.rb")}"

    vars {
        region = "${var.s3_region}"
        bucket_name = "${var.s3_bucket_name}"
        env_name = "${terraform.workspace}"
        filename = "${var.s3_tf_filename}"
    }
}
data "template_file" "script" {
    count = "${1-var.enableS3Backend}"
    template = "${file("${path.module}/template/ssh_config.rb")}"

    vars {
        env_name = "${terraform.workspace}"
        filename = "${var.s3_tf_filename}"
    }
}
resource "null_resource" "ssh_trigger_s3" {
    count = "${var.enableS3Backend}"
    triggers {
        node_list = "${var.node_list}"
    }

    provisioner "local-exec" {
        command = "${format("cat <<\"EOF\" > \"%s\"\n%s\nEOF", "${path.root}/keys/ssh_config_${var.project}-${terraform.workspace}.rb", data.template_file.script_s3.rendered)}"
    }
}

resource "null_resource" "ssh_trigger" {
    count = "${1-var.enableS3Backend}"
    triggers {
        node_list = "${var.node_list}"
    }

    provisioner "local-exec" {
        command = "${format("cat <<\"EOF\" > \"%s\"\n%s\nEOF", "${path.root}/keys/ssh_config_${var.project}-${terraform.workspace}.rb", data.template_file.script.rendered)}"
    }
}

