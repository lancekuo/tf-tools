data "template_file" "script_s3" {
    count    = "${var.enable_s3_backend}"
    template = "${file("${path.module}/template/ssh_config_s3.rb")}"

    vars {
        region      = "${var.s3-region}"
        bucket_name = "${var.bucket_name}"
        env_name    = "${terraform.workspace}"
        filename    = "${var.filename}"
    }
}
data "template_file" "script" {
    count    = "${1-var.enable_s3_backend}"
    template = "${file("${path.module}/template/ssh_config.rb")}"

    vars {
        env_name = "${terraform.workspace}"
        filename = "${var.filename}"
    }
}
data "template_file" "script_ibm" {
    count    = "${var.isIBM}"
    template = "${file("${path.module}/template/ssh_config_ibm.rb")}"

    vars {
        env_name    = "${terraform.workspace}"
        project     = "${var.project}"
        filename    = "${var.filename}"
        s3_enabled  = "false"
        region      = ""
        bucket_name = ""
    }
}
resource "null_resource" "ssh_trigger_ibm" {
    count = "${var.isIBM}"
    triggers {
        node_list = "${var.node_list}"
    }

    provisioner "local-exec" {
        command = "${format("cat <<\"EOF\" > \"%s\"\n%s\nEOF", "${path.root}/keys/ssh_config_${var.project}-${terraform.workspace}.rb", data.template_file.script_ibm.rendered)}"
    }
}

resource "null_resource" "ssh_trigger" {
    count = "${1-var.isIBM}"
    triggers {
        node_list = "${var.node_list}"
    }

    provisioner "local-exec" {
      command = "${format("cat <<\"EOF\" > \"%s\"\n%s\nEOF", "${path.root}/keys/ssh_config_${var.project}-${terraform.workspace}.rb", var.enable_s3_backend == true ? data.template_file.script.rendered : data.template_file.script_s3.rendered)}"
    }
}

