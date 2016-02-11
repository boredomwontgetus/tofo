# tofo
A manual fail-over solution for resources (ip, disk, lvm, filesystem, nfs-mount, nfs-share, ...) on linux.


## PREREQUISTES

### Perl Modules
      Config::General
      Data::Dumper
      Getopt::Long
      Tie::DxHash

### System Commands (need to be in root's $PATH)
      ip
      ping
      arping
      mount
      umount
      exportfs
      showmout
      lvs
      vgs
      lvscan
      vgchange
      lvchange
      ethtool
      df
      gcc
      VxVM commands 	#if you are going to use VxVM instead of LVM

### Files and directories
      '/proc/mounts' must be readable
      'sysfs' must be mounted and accesable


## Notes on filesystems:
  Filesystems in /etc/fstab and tofo.conf must be set using the device-mapper device. do not use the symbolic link.
  For example:
  
    right:
    /dev/mapper/myVG-myLV	/mnt/myLV           ext3 barrier=0,noauto
    
    wrong:
    /dev/myVG/myLV		/mnt/myLV           ext3 barrier=0,noauto
