output "ubuntu_ami_id" {
  value = data.aws_ami.ubuntu_ami.id
}

output "test_instances_data" {
  value = aws_instance.ubuntu_instance
}
