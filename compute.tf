#retrieve the most recent version of the preferred ami
data "aws_ami" "server_ami" {
    most_recent = true

    owners = ["099720109477"]

    filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }
}

resource "random_id" "mtc_node_id" {
  byte_length = 2
  count       = var.main_instance_count
}

#add a public_key_path in file version
resource "aws_key_pair" "mtc_auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

#create ec2 instance
resource "aws_instance" "mtc_main" {
  count                  = var.main_instance_count
  instance_type          = var.main_instance_type
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.mtc_auth.id
  vpc_security_group_ids = [aws_security_group.mtc_sg.id]
  subnet_id              = aws_subnet.mtc_public_subnet[count.index].id
 # user_data              = templatefile("./main-userdata.tpl", { new_hostname = "mtc-main-${random_id.mtc_node_id[count.index].dec}" })
  root_block_device {

    volume_size = var.main_vol_size
  }
  tags = {
    Name = "mtc-main-${random_id.mtc_node_id[count.index].dec}"
  }

  #local provisioner saves all ip address of instances created in a new file called aws_hosts
  #we can use terraform taint top destroy just the ec2 and reprovision the infrastructure
  provisioner "local-exec" {
    command = "echo '${self.public_ip}' >> aws_hosts && aws ec2 wait instance-status-ok --instance-ids ${self.id} --region us-west-2"
  }

  #local provisioner removes ip address from the aws_hosts after the insytance has been destroyed
  #loca provisioners are not recognised in the terraform state, to run a code witht he destroy command, we destroy all the resources and reprovision
#   provisioner "local-exec" {
#     when    = destroy
#     command = "PowerShell -Command \"$ipToRemove = '${self.public_ip}'; (Get-Content aws_hosts | Where-Object {$_ -ne $ipToRemove}) | Set-Content aws_hosts\""
# }

}

#remote exec provisioner to update an instance in place without any downtime
# resource "null_resource" "grafana_update" {
#   count = var.main_instance_count
#   provisioner "remote-exec" {
#     inline = ["sudo apt upgrade -y grafana && touch upgrade.log && echo 'I updated Grafana' >> upgrade.log"]

#     connection {
#       type        = "ssh"
#       user        = "ubuntu"
#       private_key = file("/home/ubuntu/.ssh/mtckey")
#       host        = aws_instance.mtc_main[count.index].public_ip
#     }
#   }
# }

# #using ansible to provison the grafana instead of userdata. using null resource and local provisioner because we want it to execute before provisioning the instances
# resource "null_resource" "grafana_install" {
#   depends_on = [aws_instance.mtc_main]
#   provisioner "local-exec" {
#     command = "ansible-playbook -i aws_hosts --key-file /home/lateefat/.ssh/mainkey playbooks/grafana.yml"
#   }
# }

output "grafana_access" {
  value = {for i in aws_instance.mtc_main[*] : i.tags.Name => "${i.public_ip}:3000"}
}


