package runcmd;


@ISA = qw(Exporter);
@EXPORT = qw(exec_ext_process);
use strict;
use IPC::Open3;



sub exec_ext_process {
  my ($cmd) = @_;
  local(*HIS_IN, *HIS_OUT, *HIS_ERR);

  my $pid = open3(*HIS_IN, *HIS_OUT, *HIS_ERR, $cmd);
  my @outlines = <HIS_OUT>;    # Read till EOF.
  my @errlines = <HIS_ERR>;    
  close HIS_IN;
  close HIS_OUT;
  close HIS_ERR;

  waitpid( $pid, 0 ); #zombie prevention
  my $rc = $? >>8; # $? needs to be binary shifted of 8bits
  return(\$rc,\@outlines,\@errlines);
}
