package srdf_warn;


@ISA = qw(Exporter);
@EXPORT = qw(print_srdf_warn);
use strict;

sub print_srdf_warn {
my ($err_stack_ref, $defined_errors_ref, $res_grp_ref) = @_;
my ($accept);
print "
 #    #    ##    #####   #    #     #    #    #   ####
 #    #   #  #   #    #  ##   #     #    ##   #  #    #
 #    #  #    #  #    #  # #  #     #    # #  #  #
 # ## #  ######  #####   #  # #     #    #  # #  #  ###
 ##  ##  #    #  #   #   #   ##     #    #   ##  #    #
 #    #  #    #  #    #  #    #     #    #    #   ####
";



print "
SRDF: You have to do the SRDF related things by yourself!!!
SRDF: Read the following lines carefully. make sure you understand what you do!!!\n";
print "
SRDF: Did you run $0 -res_grp=$$res_grp_ref -stop=all on the other node?
SRDF: Make sure you have no FS on shared LUNs mounted on the other node: 'mount'
SRDF: Make sure you have no active shared LVM groups on the other node: 'vgchange -an'

SRDF: Check for invalid SRDF tracks: 'symrdf -g <SRDF_GRP> query'
SRDF: If there are invalid tracks call EMC support

SRDF: If there are no invalid tracks do a failover: 'symrdf -g <SRDF_GRP> failover'
SRDF: Check for invalid SRDF tracks again: 'symrdf -g <SRDF_GRP> query'

SRDF: If there are invalid tracks call EMC support or the Storage Team (OnCall)

SRDF: If there are no invalid tracks do a swap: 'symrdf -g <SRDF_GRP> swap'
SRDF: Do an SRDF establish: 'symrdf -g <SRDF_GRP> establish'

SRDF: Wait until we are in sync and check that your side is now R1 and \"rw\": 'symrdf -g <SRDF_GRP> query'

If you are sure you did all the above and everything is fine and this
node is SRDF R1 and read/write able please enter 'yes, go ahead now': ";

$accept = <>;
chomp $accept;

if ($accept eq "yes, go ahead now") {
return(0);
}
else {
  main::add_err_msg_to_stack(\@main::err_stack, ${$defined_errors_ref}{err_fatal}, "SRDF WARNING not accepted by user!");
  main::print_err_and_exit();
}


}



