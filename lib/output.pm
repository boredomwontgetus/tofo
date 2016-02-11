package output;

use strict;
use vars qw(@ISA @EXPORT);
use Data::Dumper;

@ISA = qw(Exporter);
@EXPORT = qw(add_to_output print_output); 

my @output;
my $output_ref=\@output;



#add arguments to AoA
sub add_to_output {
  push (@$output_ref, [ @_ ]);
}


sub print_output {
  my($i);
  my $arr_length = scalar @{$output_ref} -1;
 
  for $i (0 .. $arr_length) {
      format_print($output_ref,\$i);
  }
  undef(@$output_ref);
}



{
  my $state; 
  sub format_print {
    my ($output_ref, $i_ref) = @_;

    #format STDOUT somehow clears the vars. this is why we transfer them.
    my $a = $output_ref->[$$i_ref]->[0];
    my $b = $output_ref->[$$i_ref]->[1];
    my $c = $output_ref->[$$i_ref]->[2];
    my $d = $output_ref->[$$i_ref]->[3];

    my $format_stdout_def_top = "format STDOUT_DEF_TOP = \n"
                                 ."RESGRP          | RESTYP   | RES                                                  | STATUS/ACTION\n"
                                 ."--------------------------------------------------------------------------------------------------\n"
                                 .".\n";
    eval $format_stdout_def_top;

    my $format_stdout_def = "format STDOUT_DEF = \n"
                            ."@<<<<<<<<<<<<<< | ^<<<<<<< | ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< | ^<<<<<<<<<<<<<<<<<<<<<\n"
                            .'$a                $b         $c                                                     $d'."\n"
                            .".\n";
    eval $format_stdout_def;


    my $format_stdout_script_top = "format STDOUT_SCRIPT_TOP = \n"
                                   ."RESGRP          | RESTYP   | SCRIPT-OUTPUT\n"
                                   ."--------------------------------------------------------------------------------------------------\n"
                                   .".\n";
    eval $format_stdout_script_top;

    my $cols = length($c);
    my $format_script  = "format STDOUT_SCRIPT = \n"
                         . '@<<<<<<<<<<<<<< | ^<<<<<<< | '
                         . '^' . '<' x $cols . "\n"
                         . '$a $b $c'. "\n"
                         . ".\n";
    eval $format_script;



    if ($d == 1) {
      $- = 0 if $state == 2;
      $^ = "STDOUT_SCRIPT_TOP";
      $~ = "STDOUT_SCRIPT";
      $state = 1;
    } 
    else {
      $- = 0 if $state == 1;
      $^ = "STDOUT_DEF_TOP";
      $~ = "STDOUT_DEF";
      $state = 2;
    }
    write;
  }
}


1;
