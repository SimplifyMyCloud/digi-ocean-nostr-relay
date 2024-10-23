packer {
  required_plugins {
    digitalocean = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/digitalocean"
    }
  }
}

source "digitalocean" "ubuntu" {
  api_token     = var.do_token
  image         = "ubuntu-22-04-x64"
  region        = "sfo3"
  size          = "s-4vcpu-8gb"
  ssh_username  = "root"
  snapshot_name = "ubuntu-nostr-relay-{{timestamp}}"

  # Enable public networking
  private_networking = false
  ipv6               = false

  # Add tags for identification
  tags = ["nostr-relay", "packer-build"]

  # Optional: Specify a droplet name for easier identification during build
  droplet_name = "nostr-relay-packer-001"
}

build {
  sources = ["source.digitalocean.ubuntu"]

  # Add a shell provisioner to capture and use the public IP
  provisioner "shell" {
    inline = [
      "export PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)",
      "echo Public IP: $PUBLIC_IP",
      "export DOMAIN_NAME=iq9.io", # Replace with your domain
      "echo \"$PUBLIC_IP $DOMAIN_NAME\" >> /etc/hosts"
    ]
  }

  provisioner "file" {
    source      = "config.toml.template"
    destination = "/tmp/config.toml"
  }

  provisioner "file" {
    source      = "nostr-rs-relay.service.template"
    destination = "/tmp/nostr-rs-relay.service"
  }

  provisioner "file" {
    source      = "nginx-nostr-rs-relay.conf.template"
    destination = "/tmp/nginx-nostr-rs-relay.conf"
  }

  provisioner "file" {
    source      = "setup_nostr.sh"
    destination = "/tmp/setup_nostr.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "DOMAIN=iq9.io",   # Replace with your domain
      "EMAIL=iq9@iq9.io" # Replace with your email
    ]
    inline = [
      "chmod +x /tmp/setup_nostr.sh",
      "/tmp/setup_nostr.sh"
    ]
  }
}