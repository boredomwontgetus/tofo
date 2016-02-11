#!/usr/bin/perl

# ./tofo.pl
# Version 0.55
#Jun 6, 2008



#----------------------------------------------------------------------------------------
#Modules
#----------------------------------------------------------------------------------------
use strict;
use Config::General qw(ParseConfig);
use Data::Dumper;
use Getopt::Long;
use Sys::Hostname;
use Tie::DxHash;
use FindBin '$Bin';


use lib "$Bin/lib/";
use err_stack;
use output;
use runcmd;
use help;
use srdf_warn;


#my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ls -l /");
#print "$$rc_ref\n\n@$outlines_ref\n\n@$errlines_ref";

#----------------------------------------------------------------------------------------
#Variable Definitions
#----------------------------------------------------------------------------------------

#config vars
#print $Bin;
my $conf_file = "$Bin/tofo.conf";
my (%config, $conf, $chkcfg);

#commandline switches
my (@start, @stop, $nosanity, $showcfg, $lstres, $lsthosts, $script_out, $res_grp, @status, $help);

#error stack library
my $err_stack_ref=\@err_stack;
my $defined_errors_ref=\%defined_errors;

#counters
my ($res_grp_count, $count);

#ressource groups and ressources
my $res;

#general vars
our $hostname = hostname();
my %status_coll;
my $status_coll_ref=\%status_coll;
our $lock;

#----------------------------------------------------------------------------------------
#Get Config from conf file
#----------------------------------------------------------------------------------------

$conf = new Config::General($conf_file);
tie %config, 'Tie::DxHash';
%config = ParseConfig (
	-ConfigFile => $conf_file,
	-Tie => "Tie::DxHash"
	);



#----------------------------------------------------------------------------------------
#Get commandline options
#----------------------------------------------------------------------------------------
GetOptions(
  "showcfg" => \$showcfg,  #showconfig params
  "lstres" => \$lstres,  #list available ressources
  "lsthosts" => \$lsthosts,  #list available hosts
  "scriptout" => \$script_out,  #list available hosts
  "res_grp=s" => \$res_grp,  #resource group name
  "status=s" => \@status,  #test all or single ressource
  "help" => \$help,  #print help and exit 
  "start=s" => \@start,  #start all or single ressource
  "stop=s" => \@stop,  #stop all or single ressource
  "nosanity" => \$nosanity
);





#----------------------------------------------------------------------------------------
#cmdline switches
#----------------------------------------------------------------------------------------

if ($showcfg) { &show_config; exit 0; }; 
if ($lstres) { &list_res; exit 0; }
if ($lsthosts) { &list_hosts; exit 0; }
if ($help) {&help; exit 0; }



#do we know the RES_GRP specified by the user?
##########################################
$res_grp_count = scalar keys %{ $config{RES} }; 
foreach $res (keys %{ $config{RES} }) {
  if ($res_grp ne $res) {
    $count++;
    next if $count ne $res_grp_count;
    &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "RES_GRP $res_grp unknown");
    &print_err_and_exit;
  }
}

@status = split(/,/, join(',',@status));
@start = split(/,/, join(',',@start));
@stop = split(/,/, join(',',@stop));

#run tests for each specified resource-type and resource_group
###########################################
foreach (@status) {
&cmdl_switches_status(\@err_stack, \%defined_errors, \$res_grp, $_)
}

#run start for each specified resource-type and resource_group
###########################################
foreach (@start) {
&cmdl_switches_start(\@err_stack, \%defined_errors, \$res_grp, $_)
}

#run stop for each specified resource-type and resource_group
###########################################
foreach (@stop) {
&cmdl_switches_stop(\@err_stack, \%defined_errors, \$res_grp, $_, $status_coll_ref)
}



###########run status##############
sub cmdl_switches_status {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status) = @_;
my $lock_status_ip = 0;
  if (($status eq "all") && $res_grp) {
    &status_ip($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref, \$lock_status_ip) if ($config{RES}{$$res_grp_ref}{NET});
    &status_routes($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) if ($config{RES}{$$res_grp_ref}{ROUTE});;
    &status_link_net($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) if ($config{RES}{$$res_grp_ref}{NET});
    &status_lv($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) if ($config{RES}{$$res_grp_ref}{FS});
    &status_vg_tags($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) if ($config{RES}{$$res_grp_ref}{LVMgroups});
    &status_mount($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) if ($config{RES}{$$res_grp_ref}{FS});
    &status_nfs_exp($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) if ($config{RES}{$$res_grp_ref}{NFSexport});
    &status_nfs_mount($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) if ($config{RES}{$$res_grp_ref}{NFSmount});
    print_output;
  }
  elsif (($status eq "ip") && $res_grp && ($config{RES}{$$res_grp_ref}{NET})) {
    &status_ip($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref, \$lock_status_ip);
    print_output;
  }
  elsif (($status eq "route") && $res_grp && ($config{RES}{$$res_grp_ref}{ROUTE})) {
    &status_routes($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref);
    print_output;
  }
  elsif (($status eq "link") && $res_grp && ($config{RES}{$$res_grp_ref}{NET})) {
    &status_link_net($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref);
    print_output;
  }
  elsif (($status eq "lv") && $res_grp && ($config{RES}{$$res_grp_ref}{FS}) ) {
    &status_lv($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref);
    print_output;
  }
  elsif (($status eq "vg") && $res_grp && ($config{RES}{$$res_grp_ref}{LVMgroups})) {
    &status_vg_tags($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref);
    print_output;
  }
  elsif (($status eq "share") && $res_grp && ($config{RES}{$$res_grp_ref}{NFSexport}) ) {
    &status_nfs_exp($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref);
    print_output;
  }
  elsif (($status eq "nfs_mount") && $res_grp && ($config{RES}{$$res_grp_ref}{NFSmount})) {
    &status_nfs_mount($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref);
    print_output;
  }
  elsif (($status eq "mount") && $res_grp && ($config{RES}{$$res_grp_ref}{FS})) {
    &status_mount($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref);
    print_output;
  }
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "unknown status option \'$status\'") if $status;
}
}



###########run start##############
sub cmdl_switches_start {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $start) = @_;
  if (($start eq "all") && $res_grp ) {
    &run_start_all_res($err_stack_ref, $defined_errors_ref, $res_grp_ref, \$nosanity);
  }
  elsif (($start eq "ip") && $res_grp && ($config{RES}{$$res_grp_ref}{NET})) {
    &run_start_ips($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($start eq "route") && $res_grp && ($config{RES}{$$res_grp_ref}{ROUTE})) {
    &run_start_routes($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($start eq "vg") && $res_grp && ($config{RES}{$$res_grp_ref}{LVMgroups}) ) {
    &run_start_vgs($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($start eq "mount") && $res_grp && ($config{RES}{$$res_grp_ref}{FS})) {
    &run_start_fs($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($start eq "share") && $res_grp  && ($config{RES}{$$res_grp_ref}{NFSexport})) {
    &run_start_nfs($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($start eq "nfs_mount") && $res_grp && ($config{RES}{$$res_grp_ref}{NFSmount})) {
    &run_start_nfs_mount($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($start eq "post_sh") && $res_grp && ($config{RES}{$$res_grp_ref}{RES_POST_start})) {
    &run_post_sh_online($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($start eq "pre_sh") && $res_grp && ($config{RES}{$$res_grp_ref}{RES_PRE_start})) {
    &run_pre_sh_online($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "unknown start option \'$start\'") if $start;
}
}


###########run stop##############
sub cmdl_switches_stop {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $stop, $status_coll_ref) = @_;
#########################stop #########################
  if (($stop eq "all") && $res_grp ) {
    &run_stop_all_res($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($stop eq "route") && $res_grp && ($config{RES}{$$res_grp_ref}{ROUTE})) {
    &run_stop_routes($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref);
  }
  elsif (($stop eq "ip") && $res_grp && ($config{RES}{$$res_grp_ref}{NET})) {
    &run_stop_ips($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref);
  }
  elsif (($stop eq "vg") && $res_grp && ($config{RES}{$$res_grp_ref}{LVMgroups})) {
    &run_stop_vgs($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($stop eq "mount") && $res_grp && ($config{RES}{$$res_grp_ref}{FS})) {
    &run_stop_fs($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($stop eq "share") && $res_grp && ($config{RES}{$$res_grp_ref}{NFSexport})) {
    &run_stop_nfs($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($stop eq "nfs_mount") && $res_grp && ($config{RES}{$$res_grp_ref}{NFSmount})) {
    &run_stop_nfs_mount($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($stop eq "post_sh") && $res_grp && ($config{RES}{$$res_grp_ref}{RES_POST_stop})) {
    &run_post_sh_offline($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
  elsif (($stop eq "pre_sh") && $res_grp && ($config{RES}{$$res_grp_ref}{RES_PRE_stop})) {
    &run_pre_sh_offline($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  }
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "unknown stop option \'$stop\'") if $stop;
}
}




#----------------------------------------------------------------------------------------
#Subroutines: worker for status
#----------------------------------------------------------------------------------------


#test if logical volumes exist by lvm
############################################################################################################################################
sub status_lv {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) = @_;
my ($fs, $fs_dev, $lv_sys);

 foreach $fs (keys %{ $config{RES}{$$res_grp_ref}{FS} }) {
      foreach $fs_dev ($config{RES}{$$res_grp_ref}{FS}{$fs}) {
        if (-b $fs_dev) {
	${$status_coll_ref}{"LV " . $fs_dev} = "0";
	add_to_output($$res_grp_ref, "LV", $fs_dev, "ONLINE");
        }
        elsif (not (-b $fs_dev)) {
	${$status_coll_ref}{"LV " . $fs_dev} = "1";
	add_to_output($$res_grp_ref, "LV", $fs_dev, "OFFLINE");
        }
      }
    }
}





#test if VG's got an LVM Tag set 
############################################################################################################################################
sub status_vg_tags {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) = @_;
my $vg_name;
my $vg_label;
my @line;

if ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 0) {
return(2) if $config{DO_HAVE_VG_TAGS} == 0;

  foreach $vg_label (keys %{ $config{RES}{$$res_grp_ref}{LVMgroups} }) {
    foreach $vg_name ($config{RES}{$$res_grp_ref}{LVMgroups}{$vg_label}) {
      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("vgs --nosuffix --noheadings $vg_name -o tags");
      my $vgs .= join('',@$outlines_ref);
      $vgs =~ s/ //g;
      if (!$vgs) {
	${$status_coll_ref}{"Host-Tag: " . $vg_name} = "1";
        add_to_output($$res_grp_ref, "VG", $vg_name, "OFFLINE");
      }
      elsif ($vgs =~ /.*$hostname.*/) {
	${$status_coll_ref}{"Host-Tag: " . $vg_name} = "0";
        add_to_output($$res_grp_ref, "VG", $vg_name, "ONLINE($hostname)");
      }
      elsif (not ($vgs =~ /.*$hostname.*/)) {
	${$status_coll_ref}{"Host-Tag: " . $vg_name} = "1";
        add_to_output($$res_grp_ref, "VG", $vg_name, "OFFLINE");
      }
    }
  }
}
elsif ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 1) {

  foreach $vg_label (keys %{ $config{RES}{$$res_grp_ref}{LVMgroups} }) {
    foreach $vg_name ($config{RES}{$$res_grp_ref}{LVMgroups}{$vg_label}) {
      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("/sbin/vxdg list | grep $vg_name");
      my $vxdg_list .= join('',@$outlines_ref);
      chomp ($vxdg_list);
      if ($vxdg_list !~ /^$vg_name\s/) {
        ${$status_coll_ref}{$vg_name} = "1";
        add_to_output($$res_grp_ref, "VG", $vg_name, "OFFLINE");
      }
      elsif ($vxdg_list =~ /^$vg_name\s/) {
        ${$status_coll_ref}{$vg_name} = "0";
        add_to_output($$res_grp_ref, "VG", $vg_name, "ONLINE");
      }
      elsif (!$vxdg_list) {
        ${$status_coll_ref}{$vg_name} = "1";
        add_to_output($$res_grp_ref, "VG", $vg_name, "OFFLINE");
      }

    }
  }



}

}



#are cluster ip's pingable?
############################################################################################################################################
sub status_ip {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref, $lock_status_ip) = @_;
my ($net_name, $ip, $ip_addr_out);

    foreach $net_name (keys %{ $config{RES}{$$res_grp_ref}{NET} }) {
      foreach $ip ($config{RES}{$$res_grp_ref}{NET}{$net_name}{ip}) {
        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ip addr show to $ip");
        $ip_addr_out .= join('',@$outlines_ref);
        ${$status_coll_ref}{$ip} = "1" if !$ip_addr_out;
        add_to_output($$res_grp_ref, "IP", $ip, "OFFLINE") if !@$outlines_ref && !$$lock_status_ip;
        ${$status_coll_ref}{$ip} = "0" if $ip_addr_out;
        add_to_output($$res_grp_ref, "IP", $ip, "ONLINE") if @$outlines_ref && !$$lock_status_ip;
      }
    }

return(0);
}

#are routes set?
############################################################################################################################################
sub status_routes {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) = @_;
my ($route_name);

    foreach $route_name (keys %{ $config{RES}{$$res_grp_ref}{ROUTE} }) {
        my ($ip_addr_out, $is_set);
        my $dest = $config{RES}{$$res_grp_ref}{ROUTE}{$route_name}{dest};
        my $gw = $config{RES}{$$res_grp_ref}{ROUTE}{$route_name}{gw};
        my $dev = $config{RES}{$$res_grp_ref}{ROUTE}{$route_name}{device};
        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ip route list to $dest");

        $ip_addr_out .= join('',@$outlines_ref);
        $is_set = 1 if $ip_addr_out =~ /$dest.+$gw.+$dev/; 
        ${$status_coll_ref}{"$dest"} = "1" if !$is_set;
        add_to_output($$res_grp_ref, "ROUTE", $dest, "OFFLINE") if !$is_set;
        ${$status_coll_ref}{$dest} = "0" if $is_set;
        add_to_output($$res_grp_ref, "ROUTE", $dest, "ONLINE") if $is_set;
    }

return(0);
}



#do NIC's have LINK?
############################################################################################################################################
sub status_link_net {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) = @_;
my ($net_name, $net_dev );

  foreach $net_name (keys %{ $config{RES}{$$res_grp_ref}{NET} }) {
      foreach $net_dev ($config{RES}{$$res_grp_ref}{NET}{$net_name}{device}) {
        my ($rc_ref_ethtool) = exec_ext_process("ethtool $net_dev 2>/dev/null | grep Link | grep -i yes");
        my ($rc_ref_mii) = exec_ext_process("grep -i up /sys/class/net/$net_dev/bonding/mii_status");
	#print "$$rc_ref_ethtool\n$$rc_ref_mii\n";
        if ($$rc_ref_ethtool == 0) {
	${$status_coll_ref}{"Link: " . $net_dev} = "0";
        add_to_output($$res_grp_ref, "LNK", $net_dev, "ONLINE");
        }
        elsif ($$rc_ref_mii == 0) {
	${$status_coll_ref}{"Link: " . $net_dev} = "0";
        add_to_output($$res_grp_ref, "LNK", $net_dev, "ONLINE");
        }
        elsif ($config{RES}{$$res_grp_ref}{NET}{$net_name}{vlan}) {
	${$status_coll_ref}{"Link: " . $net_dev} = "2";
        add_to_output($$res_grp_ref, "LNK", $net_dev, "SKIPPED(vlan device)");
        }
        else {
	  ${$status_coll_ref}{"Link: " . $net_dev} = "1";
          add_to_output($$res_grp_ref, "LNK", $net_dev, "OFFLINE");
        }
      }
    }
return(0);
}

#are any NFS shares exported?
############################################################################################################################################
sub status_nfs_exp {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) = @_;
my $nfs_name;

    foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSexport} }) {
      #  my ($rc_ref) = exec_ext_process("exportfs -v 2>/dev/null| grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}|grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{net}");
         my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir} /var/lib/nfs/etab |grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{net}");
        if ($$rc_ref == 0) {
	  ${$status_coll_ref}{"Export: " . $nfs_name} = "0";
          add_to_output($$res_grp_ref, "NFS-SHR", $nfs_name, "ONLINE");
        }
        else {
	  ${$status_coll_ref}{"Export: " . $nfs_name} = "1";
          add_to_output($$res_grp_ref, "NFS-SHR", $nfs_name, "OFFLINE");
        }
    }

return(0);
}

#are any NFS shares mounted?
############################################################################################################################################
sub status_nfs_mount {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) = @_;
my $nfs_name;

    foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSmount} }) {
        my ($rc_ref) = exec_ext_process("mount -t nfs 2>/dev/null| grep $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev} | grep $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{mntpoint}");
        if ($$rc_ref == 0) {
	  ${$status_coll_ref}{"NFS-mount: " . $nfs_name} = "0";
          add_to_output($$res_grp_ref, "NFS-MNT", $nfs_name, "ONLINE");
        }
        else {
	  ${$status_coll_ref}{"NFS-mount: " . $nfs_name} = "1";
          add_to_output($$res_grp_ref, "NFS-MNT", $nfs_name, "OFFLINE");
        }
    }

return(0);
}

#check if fs is mounted 
############################################################################################################################################
sub status_mount {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) = @_;
my ($fs, $fs_dev);

 foreach $fs (keys %{ $config{RES}{$$res_grp_ref}{FS} }) {
      foreach $fs_dev ($config{RES}{$$res_grp_ref}{FS}{$fs}) {
        my ($rc_ref) = exec_ext_process("grep \"$fs_dev \" /proc/mounts");
	${$status_coll_ref}{"Mounted: " . $fs_dev} = "1" if $$rc_ref != 0;
        add_to_output($$res_grp_ref, "FS", $fs_dev, "OFFLINE") if $$rc_ref != 0;
      	${$status_coll_ref}{"Mounted: " . $fs_dev} = "0" if $$rc_ref == 0;
        add_to_output($$res_grp_ref, "FS", $fs_dev, "ONLINE") if $$rc_ref == 0;
      }
    }
return(0);
}


#----------------------------------------------------------------------------------------
#Subroutines: worker for sanity checks
#----------------------------------------------------------------------------------------

#test if local node is mentioned in config
############################################################################################################################################
sub test_local_node {
my ($local_node);
  foreach $local_node (keys %config) {
    if ($config{$local_node} eq $hostname) {
      return(0);
    }
  }
  return(1);
}

#is srdf set or unset
############################################################################################################################################
sub test_srdf {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;

    if ($config{RES}{$$res_grp_ref}{DO_HAVE_SRDF} == 1 ) {
      return(0);
    }
    if ($config{RES}{$$res_grp_ref}{DO_HAVE_SRDF} == 0 ) {
      return(2);
    }
    else { 
      return(1);
    }  
}



#test if logical volumes exist by lvm
############################################################################################################################################
sub test_lv {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($fs, $fs_dev,$vg_label,$vg_name,$fs_lnk);

if ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 0) {
 foreach $fs (keys %{ $config{RES}{$$res_grp_ref}{FS} }) {
      foreach $fs_dev ($config{RES}{$$res_grp_ref}{FS}{$fs}) {

	foreach $vg_label (keys %{ $config{RES}{$$res_grp_ref}{LVMgroups} }) { 
    		foreach $vg_name ($config{RES}{$$res_grp_ref}{LVMgroups}{$vg_label}) {
			foreach (</dev/$vg_name/*>) {
				$fs_lnk = $_ if $fs_dev eq readlink("$_");
			}
		}
	}

        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("lvdisplay $fs_lnk 2>/dev/null | grep -i \"lv name\"");
        my $lv_sys .= join('',@$outlines_ref);
        if ($lv_sys =~ /.+$fs_lnk/) {
        add_to_output($$res_grp_ref, "LV", $fs_dev, "SANITY: OK");
        }
          elsif (not ($lv_sys =~ /!.+$fs_lnk/)) {
          &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "$fs_dev unknown by LVM") && return(1);
        }
      }
    }
return(0);
}
elsif ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 1) {
        add_to_output($$res_grp_ref, "LV", "VxVM", "SANITY: SKIPPED");
	return(10);
        }
}





#test if VG's got an LVM Tag set 
############################################################################################################################################
sub test_vg_tags {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $vg_name;
my $vg_label;
my @line;

if ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 0) {
return(2) if $config{DO_HAVE_VG_TAGS} == 0;

  foreach $vg_label (keys %{ $config{RES}{$$res_grp_ref}{LVMgroups} }) {
    foreach $vg_name ($config{RES}{$$res_grp_ref}{LVMgroups}{$vg_label}) {
      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("vgs $vg_name --noheadings -o tags");
      my $vgs .= join('',@$outlines_ref);
      chomp ($vgs);
      $vgs =~ s/ //g;
      if (!$vgs) {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "No HostTag for VG $vg_name found") && return(1);
      }
      elsif ($vgs =~ /.*$hostname.*/) {
        add_to_output($$res_grp_ref, "VG", $vg_name, "SANITY: OK");
      }
      elsif (not ($vgs =~ /.*$hostname.*/)) {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "VG: $vg_name is set to $vgs") && return(1);
      }
    }
  }
return(0);
}
elsif ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 1) {
        add_to_output($$res_grp_ref, "DG", "VxVM" , "SANITY: SKIPPED");
return(10);
}

}



#are cluster ip's pingable?
############################################################################################################################################
sub ping_ip {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($net_name, $ip);

  foreach $net_name (keys %{ $config{RES}{$$res_grp_ref}{NET} }) {
      foreach $ip ($config{RES}{$$res_grp_ref}{NET}{$net_name}{ip}) {
        my ($rc_ref) = exec_ext_process("ping -c 3 -q -W 1 $ip");
        if ($$rc_ref != 0) {
          add_to_output($$res_grp_ref, "IP", $ip , "SANITY: OK");
        }
        else {
          &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_ip}, $ip);
          return(1);
        }
      }
  }

return(0);
}

#do NIC's have LINK?
############################################################################################################################################
sub link_net {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($net_name, $net_dev);

  foreach $net_name (keys %{ $config{RES}{$$res_grp_ref}{NET} }) {
      foreach $net_dev ($config{RES}{$$res_grp_ref}{NET}{$net_name}{device}) {
        my ($rc_ref_ethtool) = exec_ext_process("ethtool $net_dev 2>/dev/null | grep Link | grep -i yes");
        my ($rc_ref_mii) = exec_ext_process("grep -i up /sys/class/net/$net_dev/bonding/mii_status");
        if ($$rc_ref_ethtool == 0) {
          add_to_output($$res_grp_ref, "LNK", $net_dev , "SANITY: OK");
        }
        elsif ($$rc_ref_mii == 0) {
          add_to_output($$res_grp_ref, "LNK", $net_dev , "SANITY: OK");
        }
        elsif ($config{RES}{$$res_grp_ref}{NET}{$net_name}{vlan}) {
        add_to_output($$res_grp_ref, "LNK", $net_dev , "SANITY: SKIPPED");
        }
        else {
          &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Link Down or Device unknown: $net_dev") && return(1);
        }
      }
    }
return(0);
}

#are any NFS shares exported?
############################################################################################################################################
sub nfs_exp {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $nfs_name;

    foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSexport} }) {
      my ($rc_ref) = exec_ext_process("exportfs -v 2>/dev/null| grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}|grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{net}");
      if ($$rc_ref != 0) {
        add_to_output($$res_grp_ref, "NFS-SHR", "$config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}" , "SANITY: OK");
      }
      else {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "$config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir} seems to be exported on $hostname") && return(1);
      }
    }

return(0);
}

#are any NFS shares mounted?
############################################################################################################################################
sub nfs_mount {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $nfs_name;

    foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSmount} }) {
      my ($rc_ref) = exec_ext_process("mount -t nfs 2>/dev/null| grep $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev} | grep $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{mntpoint}");

      if ($$rc_ref != 0) {
        add_to_output($$res_grp_ref, "NFS-MNT", "$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev}" , "SANITY: OK");
        }
        else {
      #    &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev} seems to be mounted") && return(1);
        add_to_output($$res_grp_ref, "NFS-MNT", "$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev}" , "SANITY: IS_MNT");
        }
    }

return(0);
}



#----------------------------------------------------------------------------------------
#Subroutines: worker start res/res_grps 
#----------------------------------------------------------------------------------------


#bring VG's online
###################################################################################################################################
sub vg_online {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $vg_name;
my $vg_label;
if ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 0) {
  foreach $vg_label (keys %{ $config{RES}{$$res_grp_ref}{LVMgroups} }) {
    foreach $vg_name ($config{RES}{$$res_grp_ref}{LVMgroups}{$vg_label}) {
      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("vgchange -ay $vg_name");
      if ($$rc_ref == 0) {
        add_to_output($$res_grp_ref, "VG", $vg_name, "ONLINED");
      }
      else {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "vgchange failed to activate $vg_name");
        return(1);
      }
    }
  }
return(0);
}
elsif ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 1) {
my ($rc_ref,$vxdg_lst_ref,$errlines_ref) = exec_ext_process("vxdg list");
  foreach $vg_label (keys %{ $config{RES}{$$res_grp_ref}{LVMgroups} }) {
    foreach $vg_name ($config{RES}{$$res_grp_ref}{LVMgroups}{$vg_label}) {
      if (not (grep(m|$vg_name|, @$vxdg_lst_ref))) { 
        my ($rc_ref_import,$outlines_ref,$errlines_ref) = exec_ext_process("vxdg import $vg_name");
        if ($$rc_ref_import != 0) {
          &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "vgdg import failed to activate $vg_name");
          return(1);
        }
        my ($rc_ref_startall,$outlines_ref,$errlines_ref) = exec_ext_process("vxvol -g $vg_name startall");
        if ($$rc_ref_startall != 0) {
          &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "vxvol failed to startall volumes in DG: $vg_name");
          return(1);
        }
        add_to_output($$res_grp_ref, "DG", $vg_name, "ONLINED");
    }
      else {
        my ($rc_ref_startall,$outlines_ref,$errlines_ref) = exec_ext_process("vxvol -g $vg_name startall");
        add_to_output($$res_grp_ref, "DG", $vg_name, "SKIPPED");
        next;
      }
      
	
  }
}
return(0);
}
}


#bring IP's online
###################################################################################################################################
sub ip_online {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($bin, $net_name, @lst, $sum, $ip);



    foreach $net_name (keys %{ $config{RES}{$$res_grp_ref}{NET} }) {
      $sum=0;
      foreach $ip ($config{RES}{$$res_grp_ref}{NET}{$net_name}{ip}) {
	#dec subnet to oct
        foreach ( split(/\./, $config{RES}{$$res_grp_ref}{NET}{$net_name}{mask})) {
          $bin = sprintf( "%b", $_ );
          @lst = split(//, $bin);
          $sum = $sum+$_ foreach @lst;
        }
        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ip addr show to $ip");
        my $ip_addr_out .= join('',@$outlines_ref);
	#add_to_output($$res_grp_ref, "IP", $ip, "SKIPPED")and return(0) if $ip_addr_out;
	add_to_output($$res_grp_ref, "IP", $ip, "SKIPPED") and next if $ip_addr_out;

        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ip addr add $ip/$sum dev $config{RES}{$$res_grp_ref}{NET}{$net_name}{device}");
        if ($$rc_ref != 0) {
          &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Failed to bring up $ip");
          return(1);
        }
        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("/sbin/arping -c 3 -U -I $config{RES}{$$res_grp_ref}{NET}{$net_name}{device} $ip");
	add_to_output($$res_grp_ref, "IP", $ip, "ONLINED");
      }
    }

return(0);


}


#bring routes online
###################################################################################################################################
sub routes_online {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($route_name);



    foreach $route_name (keys %{ $config{RES}{$$res_grp_ref}{ROUTE} }) {
        my $dest = $config{RES}{$$res_grp_ref}{ROUTE}{$route_name}{dest};
        my $gw = $config{RES}{$$res_grp_ref}{ROUTE}{$route_name}{gw};
        my $dev = $config{RES}{$$res_grp_ref}{ROUTE}{$route_name}{device};

        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ip route show to $dest");
        my $ip_addr_out .= join('',@$outlines_ref);
	add_to_output($$res_grp_ref, "ROUTE", $dest, "SKIPPED") and next if $ip_addr_out;

        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ip route add $dest via $gw dev $dev");
        if ($$rc_ref != 0) {
          &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Failed to add route $dest via $gw");
          return(1);
        }
	add_to_output($$res_grp_ref, "ROUTE", $dest, "ONLINED");
    }

return(0);


}

#bring mounts online
############################################################################################################################################
sub fs_online {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($fs, $fs_dev);

 foreach $fs (keys %{ $config{RES}{$$res_grp_ref}{FS} }) {
      foreach $fs_dev ($config{RES}{$$res_grp_ref}{FS}{$fs}) {

        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("grep \"$fs_dev \" /proc/mounts");
        add_to_output($$res_grp_ref, "FS", $fs_dev, "SKIPPED") and next if $$rc_ref == 0;
        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("mount $fs_dev");
        add_to_output($$res_grp_ref, "FS", $fs_dev, "ONLINED");
      }
    }
return(0);
}

#bring nfs SHARES online
############################################################################################################################################
sub nfs_online {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $nfs_name;

    foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSexport} }) {
      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("exportfs $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{opt} $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{net}:$config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}");

      if ($$rc_ref == 0) {
        add_to_output($$res_grp_ref, "NFS-SHR", "$config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{net}:$config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}", "ONLINED");
      }
      else {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Failed to share nfs ressource $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}") && return(1);
        }
    }

return(0);
}

#bring NFS mounts online
############################################################################################################################################
sub nfs_mount_online {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $nfs_name;

    foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSmount} }) {
      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("grep $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{mntpoint} /proc/mounts");
      add_to_output($$res_grp_ref, "NFS-MNT", $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{mntpoint}, "SKIPPED") and next if $$rc_ref == 0;

      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("mount -t nfs $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{opt} $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev} $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{mntpoint}");
      if ($$rc_ref == 0) { 
        add_to_output($$res_grp_ref, "NFS-MNT", "$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev}", "ONLINED");
      }
      else {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "failed to mount $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev} to $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{mntpoint}") && return(1);
      }
    }

return(0);
}

#start prescripts 
############################################################################################################################################
sub pre_sh_online {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $sh_name;
my $sh_label;

    foreach $sh_label (keys %{ $config{RES}{$$res_grp_ref}{RES_PRE_start} }) {
      foreach $sh_name ($config{RES}{$$res_grp_ref}{RES_PRE_start}{$sh_label}) {
        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("$sh_name");
        add_to_output($$res_grp_ref, "PRE-SH", $sh_name, "RUN-NCHK");
        foreach (@$outlines_ref, @$errlines_ref) {
          add_to_output($$res_grp_ref, "PRE-SH", "$_", '1') if $script_out;
        }
      }
    }

return(0);
}

#start postscripts 
############################################################################################################################################
sub post_sh_online {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $sh_name;
my $sh_label;

    foreach $sh_label (keys %{ $config{RES}{$$res_grp_ref}{RES_POST_start} }) {
      foreach $sh_name ($config{RES}{$$res_grp_ref}{RES_POST_start}{$sh_label}) {
        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("$sh_name");
        add_to_output($$res_grp_ref, "POST-SH", $sh_name, "RUN-NCHK");
        foreach (@$outlines_ref, @$errlines_ref) {
          add_to_output($$res_grp_ref, "PRE-SH", "$_", '1') if $script_out;
        }
      }
    }

return(0);
}




#----------------------------------------------------------------------------------------
#Subroutines: worker stop res/res_grps
#----------------------------------------------------------------------------------------


#bring VG's offline
###################################################################################################################################
sub vg_offline {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $vg_name;
my $vg_label;

if ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 0) {
  foreach $vg_label (keys %{ $config{RES}{$$res_grp_ref}{LVMgroups} }) {
    foreach $vg_name ($config{RES}{$$res_grp_ref}{LVMgroups}{$vg_label}) {
      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("vgchange -an $vg_name");
      if ($$rc_ref == 0) {
        add_to_output($$res_grp_ref, "VG", $vg_name, "OFFLINED");
      }
      else {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "vgchange failed to deactivate $vg_name");
        return(1);
     }
    }
  }
return(0);
}
elsif ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 1) {
  my ($rc_ref,$vxdg_lst_ref,$errlines_ref) = exec_ext_process("vxdg list");
  foreach $vg_label (keys %{ $config{RES}{$$res_grp_ref}{LVMgroups} }) {
    foreach $vg_name ($config{RES}{$$res_grp_ref}{LVMgroups}{$vg_label}) {
      if ((grep(m|$vg_name|, @$vxdg_lst_ref))) { 
      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("vxvol -g $vg_name stopall");
      if ($$rc_ref != 0) {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "vxvol failed to stopall volumes in DG: $vg_name");
        return(1);
      }
      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("vxdg deport $vg_name");
      if ($$rc_ref != 0) {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "vgdg deport failed to deactivate $vg_name");
        return(1);
      }
      add_to_output($$res_grp_ref, "DG", $vg_name, "OFFLINED");
    }
    else {
      add_to_output($$res_grp_ref, "DG", $vg_name, "SKIPPED");
      next;
    }
      
	
  }
}
}
return(0);
}


#bring IP's offline
###################################################################################################################################
sub ip_offline {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) = @_;
my ($bin, $net_name, $sum, @lst, $ip);

foreach $net_name (keys %{ $config{RES}{$$res_grp_ref}{NET} }) {
  $sum=0;
  foreach $ip ($config{RES}{$$res_grp_ref}{NET}{$net_name}{ip}) {
    #dec subnet to oct
    foreach ( split(/\./, $config{RES}{$$res_grp_ref}{NET}{$net_name}{mask})) {
      $bin = sprintf( "%b", $_ );
      @lst = split(//, $bin);
      $sum = $sum+$_ foreach @lst;
    }
    if (${$status_coll_ref}{$ip} eq "1") {
      add_to_output($$res_grp_ref, "IP", $ip, "SKIPPED");
      next;
    }
 	
    my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ip addr del $ip/$sum dev $config{RES}{$$res_grp_ref}{NET}{$net_name}{device}");
    if ($$rc_ref == 0) {  
      add_to_output($$res_grp_ref, "IP", $ip, "OFFLINED");
    }
    else {
      &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Failed to bring down $ip");
      return(1);
    }
  }
}

return(0);
}


#bring routes offline
###################################################################################################################################
sub routes_offline {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($route_name);

    foreach $route_name (keys %{ $config{RES}{$$res_grp_ref}{ROUTE} }) {
        my ($ip_addr_out, $is_set);
        my $dest = $config{RES}{$$res_grp_ref}{ROUTE}{$route_name}{dest};
        my $gw = $config{RES}{$$res_grp_ref}{ROUTE}{$route_name}{gw};
        my $dev = $config{RES}{$$res_grp_ref}{ROUTE}{$route_name}{device};

        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ip route show to $dest");
        $ip_addr_out .= join('',@$outlines_ref);
        $is_set = 1 if $ip_addr_out =~ /$dest.+$gw.+$dev/; 
	add_to_output($$res_grp_ref, "ROUTE", $dest, "SKIPPED") and next if !$is_set;

        my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ip route del $dest via $gw dev $dev");
        if ($$rc_ref != 0) {
          &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Failed to del route $dest via $gw");
          return(1);
        }
	add_to_output($$res_grp_ref, "ROUTE", $dest, "OFFLINED");
    }

return(0);


}

#bring mounts offline
############################################################################################################################################
sub fs_offline {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
open (PROC_MNTS, "/proc/mounts") || &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Could not open File /proc/mounts") && return(1);
my @proc_mounts = <PROC_MNTS>;
my $order = "rev";
my (%mounts, $fs, $fs_dev, $rc, $lock1);

foreach $fs (keys %{ $config{RES}{$$res_grp_ref}{FS} }) {
  foreach $fs_dev ($config{RES}{$$res_grp_ref}{FS}{$fs}) {
    if(($rc = &fs_deps(\$fs_dev, \%mounts, \@proc_mounts, \$order) == 0)) {	
      foreach (@{$mounts{$fs_dev}}) {
      next if !$_;

      seek PROC_MNTS, 0, 0;
      @proc_mounts = <PROC_MNTS>;
      if (not (grep(m|$fs_dev|, @proc_mounts))) { 
        add_to_output($$res_grp_ref, "FS", $_, "SKIPPED");
        next;
      }

      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("umount $_");

      if ($$rc_ref != 0) {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Failed to unmount $_");
        return(1);
      }
        add_to_output($$res_grp_ref, "FS", $_, "OFFLINED");
        $lock1 = 1;

      }
    }
  #get a SKIPPED if all filesystems are unmounted already instead of no output
    seek PROC_MNTS, 0, 0;
    @proc_mounts = <PROC_MNTS>;

    if (not (grep(m|$fs_dev|, @proc_mounts)) && !$lock1) { 
      add_to_output($$res_grp_ref, "FS", $fs_dev, "SKIPPED");  
      next;
    }
  }
}



#print Dumper(\%mounts);
close(PROC_MNTS);
return(0);
}

#bring nfs SHARES offline
############################################################################################################################################
sub nfs_offline {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $nfs_name;

foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSexport} }) {
  my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("exportfs -u $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{net}:$config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}");
  if ($$rc_ref == 0) {
    add_to_output($$res_grp_ref, "NFS-SHR", "$config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{net}:$config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}", "OFFLINED");
  }
  else {
    &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Failed to unshare nfs ressource $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}") && return(1);
  }
}
return(0);
}

#bring NFS mounts offline
############################################################################################################################################
sub nfs_mount_offline {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $nfs_name;
foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSmount} }) {
  my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("cat /proc/mounts | grep -P \"$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev}\\s\"");
  if ($$rc_ref != 0) {
    add_to_output($$res_grp_ref, "NFS-MNT", "$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev}", "SKIPPED");
    next;
  }

  my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("umount -t nfs $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{mntpoint}");
  if ($$rc_ref == 0) {
    add_to_output($$res_grp_ref, "IP", "$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev}", "OFFLINED");
  }
  else {
    &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "failed to umount $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev} to $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{mntpoint}");
    return(1);
  }
}

return(0);
}

#stop prescripts 
############################################################################################################################################
sub pre_sh_offline {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $sh_name;
my $sh_label;

foreach $sh_label (keys %{ $config{RES}{$$res_grp_ref}{RES_PRE_stop} }) {
  foreach $sh_name ($config{RES}{$$res_grp_ref}{RES_PRE_stop}{$sh_label}) {
    my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("$sh_name");
    add_to_output($$res_grp_ref, "PRE-SH", $sh_name, "RUN-NCHK");
    foreach (@$outlines_ref, @$errlines_ref) {
      add_to_output($$res_grp_ref, "PRE-SH", "$_", '1') if $script_out;
    }
  }
}

return(0);
}

#stop postscripts 
############################################################################################################################################
sub post_sh_offline {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $sh_name;
my $sh_label;

foreach $sh_label (keys %{ $config{RES}{$$res_grp_ref}{RES_POST_stop} }) {
  foreach $sh_name ($config{RES}{$$res_grp_ref}{RES_POST_stop}{$sh_label}) {
    my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("$sh_name");
    add_to_output($$res_grp_ref, "POST-SH", $sh_name, "RUN-NCHK");
    foreach (@$outlines_ref, @$errlines_ref) {
      add_to_output($$res_grp_ref, "PRE-SH", "$_", '1') if $script_out;
    }
  }
}

return(0);
}





















#----------------------------------------------------------------------------------------
#Subroutines: worker post test res/res_grps start
#----------------------------------------------------------------------------------------

#check if lv's in vg are realy online after vgchange -ay
#############################################################################################################################################################################
sub vg_online_post_chk {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($vg_name, $vg_label, @lv_status, $vg_status);

if ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 0) {
  foreach $vg_label (keys %{ $config{RES}{$$res_grp_ref}{LVMgroups} }) {
    foreach $vg_name ($config{RES}{$$res_grp_ref}{LVMgroups}{$vg_label}) {
      my ($rc_ref,$lv_status_ref,$errlines_ref) = exec_ext_process("lvs --noheadings $vg_name -o lv_attr");
      &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "VG: $vg_name failed to bring all LV's online! (Postchk failed)") && return(1) if not @$lv_status_ref;
      foreach (@$lv_status_ref) {
        chomp;
        s/ //g;
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "VG: $vg_name failed to bring all LV's online! (Postchk failed)") && return(1) if not /....a./;
      }
    }
  }
return(0);
}
elsif ($config{RES}{$$res_grp_ref}{DO_HAVE_VxVM} == 1) {
  foreach $vg_label (keys %{ $config{RES}{$$res_grp_ref}{LVMgroups} }) {
    foreach $vg_name ($config{RES}{$$res_grp_ref}{LVMgroups}{$vg_label}) {
      my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("vxdg list 2>/dev/null | grep $vg_name");
      my $vg_status .= join('',@$outlines_ref);
      my ($rc_ref,$lv_status_ref,$errlines_ref) = exec_ext_process("vxinfo -g $vg_name");
      &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "VG: $vg_name failed to bring all LV's online! (Postchk failed)") && return(1) if not @$lv_status_ref;
      &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "VG: $vg_name failed to enable! (Postchk failed)") && return(1) if not $vg_status =~/$vg_name\s+enabled.*/;
      foreach (@lv_status) {
        chomp;
      &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_lvm}, "VG: $vg_name failed to bring all LV's online! (Postchk failed)") && return(1) if not grep(m|Started|, $_);
      }
    }
  }
return(0);
}
}

#check if if ip's are up on localhost after ip addr add
#############################################################################################################################################################################

sub ip_online_post_chk {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($ip_addr_out, $net_name, $ip, $ip_addr_out);

foreach $net_name (keys %{ $config{RES}{$$res_grp_ref}{NET} }) {
  foreach $ip ($config{RES}{$$res_grp_ref}{NET}{$net_name}{ip}) {
    my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("ip addr show to $ip");
    $ip_addr_out .= join('',@$outlines_ref);
    &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Postchk for $ip failed") && return(1) if !$ip_addr_out;
  }
}

return(0);
}

#check if fs is mounted after fs_online 
############################################################################################################################################
sub fs_online_post_chk {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($fs, $fs_dev,);

foreach $fs (keys %{ $config{RES}{$$res_grp_ref}{FS} }) {
  foreach $fs_dev ($config{RES}{$$res_grp_ref}{FS}{$fs}) {
    my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("grep $fs_dev /proc/mounts");
      if ($$rc_ref != 0) {
        &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "POSTchk failed:  $fs_dev seems to be not mounted");
        return(1);
      }
  }
}
return(0);
}

#check if NFS shares exported after nfs_online
############################################################################################################################################
sub nfs_online_post_chk {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $nfs_name;

foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSexport} }) {
  #my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("exportfs -v 2>/dev/null| grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}|grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{net}");
  my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir} /var/lib/nfs/etab |grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{net}");
  if ($$rc_ref != 0) {
    &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "failed to nfs export $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}");
     return(1);
  }
}

return(0);
}

#check if NFS shares unexported after nfs_offline
############################################################################################################################################
sub nfs_offline_post_chk {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $nfs_name;

foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSexport} }) {
  my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("exportfs -v 2>/dev/null| grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}|grep $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{net}"); 
  if ($$rc_ref == 0) {
    &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "failed to nfs unexport $config{RES}{$$res_grp_ref}{NFSexport}{$nfs_name}{dir}") && return(1);
  }
}

return(0);
}

#are any NFS shares mounted after nfs_mount_online
############################################################################################################################################
sub nfs_mount_online_post_chk {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my $nfs_name;

foreach $nfs_name (keys %{ $config{RES}{$$res_grp_ref}{NFSmount} }) {
  my ($rc_ref,$outlines_ref,$errlines_ref) = exec_ext_process("mount -t nfs 2>/dev/null| grep $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev}");
  if ($$rc_ref != 0) {
    &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_misc}, "Failed to mount $config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{host}:$config{RES}{$$res_grp_ref}{NFSmount}{$nfs_name}{dev}") && return(1);
  }
}

return(0);
}





























#----------------------------------------------------------------------------------------
#Subroutines: Running the Tests 
#----------------------------------------------------------------------------------------

sub run_test_ip {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);
#test ip adresses
if (($rc=&ping_ip(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "IP Subroutine Exited with an Error!");
print_output if !$lock;
  &print_err_and_exit;
}
print_output if !$lock;
}

sub run_test_link {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);
if (($rc=&link_net(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "link_net Subroutine Exited with an Error!");
print_output if !$lock;
  &print_err_and_exit;
}
print_output if !$lock;
}

#test if LV is known by LVM 
sub run_test_lvm_knows {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);
if (($rc=&test_lv(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "test_lv Subroutine Exited with an Error!");
print_output if !$lock;
  &print_err_and_exit;
}
elsif (($rc) == 10) {
  return(0)
}
print_output if !$lock;
}

#test if VG has correct hosttag
sub run_test_vg_tags {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);
if (($rc=&test_vg_tags(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "vg_tags Subroutine Exited with an Error!");
print_output if !$lock;
  &print_err_and_exit;
}
elsif (($rc) == 2) {
}
elsif (($rc) == 10) {
  return(0)
}
print_output if !$lock;


}
sub run_test_local_node {
my ($rc);
#is localnode in config file
if (($rc=&test_local_node) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "LocalNode not in Config!");
print_output if !$lock;
  &print_err_and_exit;
}


}

sub run_test_nfs_exp {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);
if (($rc=&nfs_exp(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "nfs_exp Subroutine Exited with an Error!!");
print_output if !$lock;
  &print_err_and_exit;
}
print_output if !$lock;
}

sub run_test_nfs_mount {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);
if (($rc=&nfs_mount(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "nfs_mount Subroutine Exited with an Error!!");
print_output if !$lock;
  &print_err_and_exit;
}
print_output if !$lock;
}

#if SRDF enabled tell user what to do
sub run_test_srdf {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);
if (($rc=&test_srdf(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
 # print "SRDF Enabled\n";
        add_to_output($$res_grp_ref, "SRDF", "ENABLED", "SANITY: OK");
 &print_srdf_warn(\@err_stack, \%defined_errors, $res_grp_ref);
}
elsif (($rc) == 2) {
#  print "SRDF Disabled\n";
        add_to_output($$res_grp_ref, "SRDF", "ENABLED", "SANITY: NOK");
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_config}, "SRDF");
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "SRDF");
print_output if !$lock;
  &print_err_and_exit;
}
elsif (($rc) == 5) {
  return;
}
print_output if !$lock;
}



#----------------------------------------------------------------------------------------
#Subroutines: Running Start 
#----------------------------------------------------------------------------------------

####################start VG's
sub run_start_vgs {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&vg_online(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "vg_online Subroutine Exited with an Error!");
  &print_err_and_exit;
}
#postchk
if (($rc=&vg_online_post_chk(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "vg_online_post_chk Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}


####################start IP's
sub run_start_ips {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&ip_online(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "ip_online Subroutine Exited with an Error!");
  &print_err_and_exit;
}
#postchk
if (($rc=&ip_online_post_chk(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "ip_online_post_chk Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

####################start routes
sub run_start_routes {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&routes_online(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "routes_online Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}


####################start FS's
sub run_start_fs {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&fs_online(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "fs_online Subroutine Exited with an Error!");
  &print_err_and_exit;
}
#postchk
if (($rc=&fs_online_post_chk(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "fs_online_post_chk Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}
####################start NFS shares
sub run_start_nfs {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&nfs_online(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "nfs_online Subroutine Exited with an Error!");
  &print_err_and_exit;
}
#postchk
if (($rc=&nfs_online_post_chk(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "nfs_online_post_chk Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

####################start NFS mounts
sub run_start_nfs_mount {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&nfs_mount_online(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "nfs_mount_online Subroutine Exited with an Error!");
  &print_err_and_exit;
}
#postchk
if (($rc=&nfs_mount_online_post_chk(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "nfs_mount_online_post_chk Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

####################start pre_sh_online
sub run_pre_sh_online {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&pre_sh_online(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "pre_sh_online Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

####################start post_sh_online
sub run_post_sh_online {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&post_sh_online(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "post_sh_online Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}




#----------------------------------------------------------------------------------------
#Subroutines: Running Stop 
#----------------------------------------------------------------------------------------

####################stop VG's
sub run_stop_vgs {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&vg_offline(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "vg_offline Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

####################stop routes
sub run_stop_routes {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) = @_;
my ($rc);
if (($rc=&routes_offline(\@err_stack, \%defined_errors, $res_grp_ref, $status_coll_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "route_offline Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

####################stop IP's
sub run_stop_ips {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) = @_;
my ($rc);
my $lock_stauts_ip = 1;
&status_ip($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref, \$lock_stauts_ip) if ($config{RES}{$$res_grp_ref}{NET});
if (($rc=&ip_offline(\@err_stack, \%defined_errors, $res_grp_ref, $status_coll_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "ip_offline Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}
####################stop FS's
sub run_stop_fs {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&fs_offline(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
elsif (($rc) == 1) {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "fs_offline Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

####################stop NFS shares
sub run_stop_nfs {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&nfs_offline(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "nfs_offline Subroutine Exited with an Error!");
  &print_err_and_exit;
}
#postchk
if (($rc=&nfs_offline_post_chk(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "nfs_offline_post_chk Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

####################stop NFS mounts
sub run_stop_nfs_mount {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&nfs_mount_offline(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "nfs_mount_offline Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

####################stop pre_sh_offline
sub run_pre_sh_offline {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&pre_sh_offline(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "pre_sh_offline Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

####################stop post_sh_offline
sub run_post_sh_offline {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

if (($rc=&post_sh_offline(\@err_stack, \%defined_errors, $res_grp_ref)) == 0) {
}
else {
  &add_err_msg_to_stack(\@err_stack, ${$defined_errors_ref}{err_fatal}, "post_sh_offline Subroutine Exited with an Error!");
  &print_err_and_exit;
}
print_output if !$lock;
}

















sub run_test_all_res {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);

print "###################################\nRunning Sanity Check Sequences\n###################################\n";
&run_test_local_node(\@err_stack, \%defined_errors);

$lock=1; #used to not run print_output in in run_start* if called from run_start_all_res

  &run_test_srdf($err_stack_ref, $defined_errors_ref, $res_grp_ref);
  &run_test_ip($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{NET};
  &run_test_link($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{NET};
  &run_test_lvm_knows($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{FS};
  &run_test_vg_tags($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{LVMgroups};
  &run_test_nfs_exp($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{NFSexport};
  &run_test_nfs_mount($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{NFSmount};

print_output;
}


################################################

sub run_start_all_res {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref, $nosanity_ref) = @_;
my ($rc);
&run_test_all_res(\@err_stack, \%defined_errors, $res_grp_ref) if !$$nosanity_ref;
$lock=1; #used to not run print_output in run_start* if called from run_start_all_res

print "###################################\nRunning START Sequences\n###################################\n";

  &run_pre_sh_online($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{RES_PRE_start};
  &run_start_vgs($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{LVMgroups};
  &run_start_ips($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{NET};
  &run_start_routes($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{ROUTE};
  &run_start_fs($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{FS};
  &run_start_nfs($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{NFSexport};
  &run_start_nfs_mount($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{NFSmount};
  &run_post_sh_online($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{RES_POST_start};
print_output;
}

################################################

################################################

sub run_stop_all_res {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($rc);
$lock=1; #used to not run print_output in in run_start* if called from run_start_all_res

print "###################################\nRunning STOP Sequences\n###################################\n";

    &run_pre_sh_offline($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{RES_PRE_stop};
    &run_stop_nfs_mount($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{NFSmount};
    &run_stop_nfs($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{NFSexport};
    &run_stop_routes($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) if $config{RES}{$$res_grp_ref}{ROUTE};
    &run_stop_ips($err_stack_ref, $defined_errors_ref, $res_grp_ref, $status_coll_ref) if $config{RES}{$$res_grp_ref}{NET};
    &run_stop_fs($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{FS};
    &run_stop_vgs($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{LVMgroups};
    &run_post_sh_offline($err_stack_ref, $defined_errors_ref, $res_grp_ref) if $config{RES}{$$res_grp_ref}{RES_POST_stop};

print_output;
}

################################################
























#----------------------------------------------------------------------------------------
#Subroutines: helpers 
#----------------------------------------------------------------------------------------

#Subroutine for dumping configured ressource groups
#######################################
sub list_res {
  foreach my $res (keys %{ $config{RES} }) {
    print "$res\n";
  } 
  return(0);
}

#Subroutine for dumping configured hosts 
#######################################
sub list_hosts {
  foreach my $nodes (keys %config) {
    print "$nodes=$config{$nodes}\n" if $nodes =~ /^node\d+/;
  } 
}


#Subroutine for dumping configuration
#######################################

sub show_config {
print "############################################
Configuration read from $conf_file: 
############################################\n"
. Dumper(\%config) 
. "###################################################\n"; 
}


#find fs that depend on $fs_dev and unmount them first
##########################################################
sub fs_deps {
my ($fs_dev_ref, $mounts_ref, $proc_mounts_ref, $order_ref) = @_;
my (@line, @aha, @line1, @aha2);
#\Q in m|| causes chars like '.' '+' to be treated as regular characters. \E ands this behaveiour
        if (@line = grep(m|\Q$$fs_dev_ref\E\s+|, @{$proc_mounts_ref})) {
        foreach (@line) {
          chomp;
          @aha = split(/ /, $_);
#\Q in m|| causes chars like '.' '+' to be treated as regular characters.
          @line1 = grep(m|\Q$aha[1]|, @{$proc_mounts_ref});
          foreach (@line1) {
            chomp $_;
            @aha2 = split(/ /, $_);
            push (@{$$mounts_ref{$$fs_dev_ref}}, $aha2[1]); 
          }
        } 
        @{$$mounts_ref{$$fs_dev_ref}} = sort { length $b <=> length $a } @{$$mounts_ref{$$fs_dev_ref}} if $$order_ref eq "rev";
        @{$$mounts_ref{$$fs_dev_ref}} = sort { length $a <=> length $b } @{$$mounts_ref{$$fs_dev_ref}} if $$order_ref eq "nor";

}
else { return(0); }
}


#print whole error stack and exit(1)
####################################################
sub print_err_and_exit {
print "\n";
&print_err_stack(\@err_stack);
exit(1);
}


