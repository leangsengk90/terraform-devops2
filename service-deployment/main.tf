data "terraform_remote_state" "swarm" {
  backend = "s3"
  config = {
    bucket = "devops-group4-prod"
    key    = "docker-swarm/terraform.tfstate"
    region = "ap-southeast-1"
  }
}


resource "null_resource" "deploy_service" {
  count = length(var.services)

  provisioner "file" {
    source      = "${path.module}/${var.services[count.index].compose_file}"
    destination = "/home/ec2-user/${var.services[count.index].compose_file}"
    connection {
      type        = "ssh"
      host        = data.terraform_remote_state.swarm.outputs.swarm_master_public_ip
      user        = "ec2-user"
      private_key = file(var.ssh_key_path)
    }
  }

  provisioner "remote-exec" {
    inline = [
      "docker stack deploy -c /home/ec2-user/${var.services[count.index].compose_file} ${var.services[count.index].stack_name}"
    ]
    connection {
      type        = "ssh"
      host        = data.terraform_remote_state.swarm.outputs.swarm_master_public_ip
      user        = "ec2-user"
      private_key = file(var.ssh_key_path)
    }
  }
}
