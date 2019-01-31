provider "packet" {
  auth_token = "${var.packet_auth_token}"
}

provider "external" {
  version = "~> 1.0"
}

# fetch OS id from packet
data "packet_operating_system" "esxi" {
  name             = "VMware ESXi 6.5"
  distro           = "vmware"
  version          = "6.5"
  provisionable_on = "${var.packet_device_plan}"
}

# create the datastore volume
# packet_volume doesn't have a name argument :(
resource "packet_volume" "datastore" {
  description   = "vshpere data store"
  facility      = "sjc1"
  project_id    = "${var.packet_project_id}"
  plan          = "${var.packet_storage_plan}"
  size          = 500
  billing_cycle = "hourly"
}

# deploy esxi host
resource "packet_device" "esxi" {
  hostname         = "${var.esxi_hostname}"
  plan             = "${var.packet_device_plan}"
  facility         = "sjc1"
  operating_system = "${data.packet_operating_system.esxi.id}"
  billing_cycle    = "hourly"
  project_id       = "${var.packet_project_id}"

  # pause for 300 seconds as the host might not be ready immediately
  provisioner "local-exec" {
    command = <<EOF
echo "pause for 300 seconds"; \
for i in {1..300}; \
do \
echo "current time: `date +%c`"; \
sleep 1; \
done;
EOF
  }

  # generate the bootstrap script
  provisioner "local-exec" {
    command = "${path.module}/files/gen_esxi_mod.sh ${var.packet_auth_token} ${packet_volume.datastore.id} ${var.esxi_admin_username} ${var.esxi_admin_password}"
  }

  depends_on = ["packet_volume.datastore"]
}

# attach volume to the machine
resource "packet_volume_attachment" "attach_volume" {
  device_id = "${packet_device.esxi.id}"
  volume_id = "${packet_volume.datastore.id}"

  connection {
    host        = "${packet_device.esxi.access_public_ipv4}"
    type        = "ssh"
    user        = "root"
    private_key = "${file("~/.ssh/id_rsa")}"
  }

  # run bootstrap script on esxi
  provisioner "remote-exec" {
    script = "${path.module}/files/esxi_tmp.sh"
  }

  # pause for 60 seconds to allow the networking modifications to take effect
  provisioner "local-exec" {
    command = <<EOF
echo "pause for 60 seconds"; \
for i in {1..60}; \
do \
echo "current time: `date +%c`"; \
sleep 1; \
done;
EOF
  }

  depends_on = ["packet_device.esxi"]
}

# fetch gw ip and expose it via output
data "external" "esxi_gw_ip" {
  program    = ["bash", "${path.module}/files/fetch_gw_ip.sh", "${var.packet_auth_token}", "${packet_device.esxi.id}"]
  depends_on = ["packet_volume_attachment.attach_volume"]
}