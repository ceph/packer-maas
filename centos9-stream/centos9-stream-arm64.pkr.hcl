packer {
  required_version = ">= 1.7.0"
  required_plugins {
    qemu = {
      version = "~> 1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "filename" {
  type        = string
  default     = "centos9-stream.tar.gz"
  description = "The filename of the tarball to produce"
}

variable "centos9_stream_iso_url" {
  type    = string
  default = "https://mirror.stream.centos.org/9-stream/BaseOS/aarch64/iso/CentOS-Stream-9-latest-aarch64-boot.iso"
}

variable "centos9_stream_sha256sum_url" {
  type    = string
  default = "https://mirror.stream.centos.org/9-stream/BaseOS/aarch64/iso/CentOS-Stream-9-latest-aarch64-boot.iso.SHA256SUM"
}

# use can use "--url" to specify the exact url for os repo
variable "ks_os_repos" {
  type    = string
  default = "--mirrorlist='https://mirrors.centos.org/metalink?repo=centos-baseos-9-stream&arch=aarch64&protocol=https,http'"
}

# use can use "--url" to specify the exact url for baseOS repo
variable "ks_baseos_repos" {
  type    = string
  default = "--metalink='https://mirrors.centos.org/metalink?repo=centos-baseos-9-stream&arch=aarch64&protocol=https,http'"
}

# Use --baseurl to specify the exact url for AppStream repo
variable "ks_appstream_repos" {
  type    = string
  default = "--metalink='https://mirrors.centos.org/metalink?repo=centos-appstream-9-stream&arch=aarch64&protocol=https,http'"
}

# Use --baseurl to specify the exact url for centos repo
variable "ks_centos_repos" {
  type    = string
  default = "--metalink='https://mirrors.centos.org/metalink?repo=centos-crb-9-stream&arch=aarch64&protocol=https,http'"
}

variable ks_proxy {
  type    = string
  default = "${env("KS_PROXY")}"
}

variable ks_mirror {
  type    = string
  default = "${env("KS_MIRROR")}"
}

variable "timeout" {
  type        = string
  default     = "3h"
  description = "Timeout for building the image"
}

locals {
  ks_proxy           = var.ks_proxy != "" ? "--proxy=${var.ks_proxy}" : ""
  ks_os_repos        = var.ks_mirror != "" ? "--url=${var.ks_mirror}/BaseOS/aarch64" : var.ks_os_repos
  ks_baseos_repos    = var.ks_mirror != "" ? "--baseurl=${var.ks_mirror}/BaseOS/aarch64" : var.ks_baseos_repos
  ks_appstream_repos = var.ks_mirror != "" ? "--baseurl=${var.ks_mirror}/AppStream/aarch64" : var.ks_appstream_repos
  ks_centos_repos    = var.ks_mirror != "" ? "--baseurl=${var.ks_mirror}/CRB/aarch64" : var.ks_centos_repos
}

source "qemu" "centos9-stream" {
  boot_command     = ["<up>e<down><down><End><wait>", " auto=true inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/centos9-stream.ks loglevel=debug inst.text inst.cmdline", "<F10>"]
  boot_wait        = "20s"
  communicator     = "none"
  disk_size        = "4G"
  headless         = true
  iso_checksum     = "file:${var.centos9_stream_sha256sum_url}"
  iso_url          = var.centos9_stream_iso_url
  memory           = 2048
  qemu_binary      = "/usr/bin/qemu-system-aarch64"
  qemuargs         = [["-serial", "mon:stdio"], ["-cpu", "host"], ["-machine", "virt,gic-version=3,accel=kvm"], [ "-boot", "menu=on" ], ["-nographic"], ["-device", "virtio-gpu-pci"], ["-device", "qemu-xhci"], ["-device", "usb-kbd"], [ "-bios", "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd" ]]
  shutdown_timeout = var.timeout
  http_content = {
    "/centos9-stream.ks" = templatefile("${path.root}/http/centos9-stream-arm64.ks.pkrtpl.hcl",
      {
        KS_PROXY           = local.ks_proxy,
        KS_OS_REPOS        = local.ks_os_repos,
        KS_BASEOS_REPOS    = local.ks_baseos_repos,
        KS_APPSTREAM_REPOS = local.ks_appstream_repos,
        KS_CENTOS_REPOS    = local.ks_centos_repos
      }
    )
  }

}

build {
  sources = ["source.qemu.centos9-stream"]

  post-processor "shell-local" {
    inline = [
      "SOURCE=${source.name}",
      "OUTPUT=${var.filename}",
      "ROOT_PARTITION=2",
      "source ../scripts/fuse-nbd",
      "source ../scripts/fuse-tar-root",
    ]
    inline_shebang = "/bin/bash -e"
    keep_input_artifact = true
  }
}
