# Proxmox/PiMox for Ten64

__This is not an official port of Proxmox__

This is a installer script for Proxmox/PiMox (Proxmox port for ARM64 machines) that
will work on the [Ten64](https://traverse.com.au/products/ten64-networking-platform/)

It's based off the original [pimox7](https://github.com/pimox/pimox7) installer script,
with tweaks to account for differences between the Raspberry Pi and Ten64
(for example, configuring GRUB to supply the kernel command line instead of RPI's `cmdline.txt`).

Just after I finished testing the pimox7/PVE7.2 port, [jiangcuo](https://github.com/jiangcuo/Proxmox-Arm64)
published a set of packages for PVE7.3. Thankfully this installer script will work with their
repository as well.

If you want to use the pimox7 package set, just edit the repository used in the install script.

Discussion thread on Traverse forum: https://forum.traverse.com.au/t/proxmox-pimox-installer-for-ten64/282/1

## Installation instructions

1. Install a fresh Debian stable (11) using the [appliance store / recovery environment](https://ten64doc.traverse.com.au/software/appliancestore/)

   `baremetal-deploy debian-stable /dev/nvme0n1`

2. Once your fresh Debian install is up and running, copy the `IA-Install.sh` script to your Ten64

3. Run the IA-Install.sh from a root prompt (sudo -i to elevate from the `debian` user) on the __serial__ console (you will lose network connectivity during the install process!)

   `debian@debian:~$ sudo -i # (elevate to root, needs to be -i to get the root user profile)`
   `root@debian:/home/debian# bash IA-Install.sh`

4. Wait for the install to finish. It will reboot automatically.

   Note: About 1GB of packages will be downloaded during the install process.

## Notes

`eth0` will be setup as the uplink for the default bridge interface `vmbr0`. 
You can change this by editing `/etc/network/interfaces`, or using the Network configuration UI in Proxmox.

When creating a VM you will need to note the following:

* You need to select UEFI as the BIOS for VMs. You will be prompted to assign a disk
  drive for UEFI variables.

* On Proxmox/PiMox 7.2, it creates a VM using IDE for the CDROM as default. This will not work.

  In the VM creation wizard, leave the CDROM unconnected.

  When the VM has been created, delete the ide2 CDROM device and create a new one using SCSI.

  In the boot order options, edit the boot order so the new scsi CDROM device is after the VM disk and PXE/network

## Troubleshooting

Sometimes the bridge interface (vmbr0) does not start automatically on boot.
You might need to login on the serial console and bring it up manually

```
ifup vmbr0
```

## Resources / More Info

* [pimox project](https://github.com/pimox/pimox7) (Proxmox rebuilt from source)
* [jiangcuo's PVE 7.3](https://github.com/jiangcuo/Proxmox-Arm64) (repackage of amd64 debs to arm64)
* There are some threads on the Proxmox forum, e.g [TUTORIAL: How to run PVE 7 on a Raspberry Pi](https://forum.Proxmox.com/threads/how-to-run-pve-7-on-a-raspberry-pi.95658/)
