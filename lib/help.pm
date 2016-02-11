package help;


@ISA = qw(Exporter);
@EXPORT = qw(help);
use strict;



sub help
{
print "
Usage: $0 [ressource group] [action] 
  
  -help                                 print this brief help message
  -lstres                               list all ressource groups defined in config file
  -lsthosts                             list all all hosts defined in config file
  -scriptout                            add STDOUT/STDERR from all pre/post scripts to tofo's output 
					this might mess up the output and make it hard to read
  -showcfg                              print config as interpreted by $0
  -nosanity                             used only with --start=all; disables santiycheck-routine before start-routine;
                                        use with caution; make sure to know what you are doing;

Ressource group options:
  -res_grp=<RES_GRP>                    specify the res_grp you want to work on

Actions:

  -status=[ressource type]              one or more (comma-seperated) ressource         
         all                            status of all ressource types of a selected ressource group
         ip                             returns status of set ip's are pingable - returns OK if set
         route                          returns status of set routes - returns OK if set
         link                           returns status of NIC's uplink - returns OK if link is up
         lv                             returns status of lvm knowledge about LV's
         vg                             returns status of VG's host-tag
         share                          returns status of exported filesystems (nfs)
         nfs_mount                      returns status of nfs-mounted filesystems
         mount                          returns status about mounted filesystems

  -start=[ressource type]               one or more (comma-seperated) ressource
         all                            start all ressource types of a selected ressource group; runs -test=all automaticaly
         ip                             set ip addresses up
         route                          set routes up
         vg                             activate volume groups
         mount                          mount filesystems
         share                          share nfs filesystems
         nfs_mount                      mount nfs filesystems
         pre_sh                         run RES_PRE_start scripts
         post_sh                        run RES_POST_start scripts

  -stop=[ressource type]                one or more (comma-seperated) ressource
         all                            stop all ressource types of a selected ressource group
         route                          take routes down
         ip                             take ip addresses down
         vg                             deactivate volume groups
         mount                          umount filesystems
         share                          unshare nfs filesystems
         nfs_mount                      umount nfs filesystems
         pre_sh                         run RES_PRE_stop scripts
         post_sh                        run RES_POST_stop scripts


";

}

