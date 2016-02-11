package err_stack;

use vars qw(@ISA @EXPORT);
use Data::Dumper;
@ISA = qw(Exporter);
@EXPORT = qw(@err_stack %defined_errors add_err_msg_to_stack print_err_stack);

my $TRACE_ERR = 1;
our @err_stack;

# possible errors for err_stack
# add them as neccesary
our (%defined_errors) = (
	err_file_or_dir => { fmt => "No such file or directory: %s"},
	err_open => { fmt => "Can not open file or directory: %s"},
	err_exec => { fmt => "Can not execute: %s"},
	err_ip => { fmt => "IP Adress seems to be up anywhere: %s"},
	err_lvm => { fmt => "LVM: %s"},
	err_config => { fmt => "Unknown Config Paramater in directive: %s"},
	err_misc => { fmt => "Misc Error: %s" },
	err_fatal => { fmt => "Fatal Sudden DEATH: %s"},
);





sub add_err_msg_to_stack {
  my($err_stack_ref, $definederr_ref, @errpars) = @_;
  push (@{$err_stack_ref}, { definederr_ref => $definederr_ref, errpars_ref => \@errpars });

return(\@err_stack);
}




sub print_err_stack {
  my ($err_stack_ref) = @_;
  my ($i, $framecount, @output); 

  if ($TRACE_ERR == 1) {
    
    #stupid perl
    $framecount = $#{$err_stack_ref}+1;
    for ($i=0; $i<$framecount; $i++) {

      printf ("ERROR[$i]: ${$err_stack_ref}[$i]{definederr_ref}{fmt}\n", @{${$err_stack_ref}[$i]{errpars_ref}});
      push(@output, sprintf("ERROR[$i]: ${$err_stack_ref}[$i]{definederr_ref}{fmt}\n", @{${$err_stack_ref}[$i]{errpars_ref}}));
    }
  }

  printf ("ERROR: ${$err_stack_ref}[0]{definederr_ref}{fmt}\n", ${$err_stack_ref}[0]{errpars_ref}[0]) if $TRACE_ERR == 0;
  push(@output, sprintf("ERROR: ${$err_stack_ref}[0]{definederr_ref}{fmt}\n", ${$err_stack_ref}[0]{errpars_ref}[0])) if $TRACE_ERR == 0;

return(@output);
}

1;
