package shadow_tools;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(get_option help_screen);


sub get_option {
    
   shift @ARGV;
   die "Error, option without a value detected.\n" unless @ARGV != 0 && $ARGV[0] !~ /-+\w/; 

}


sub help_screen {
 
   my $help_text = <<~"EOF"; 
   This is the gui version of Shadow-Tune.
   Upon startup, the program will fork to the background
   and start the server.
   Accepted commandline options are:

   -p: Specify a port to listen on (default 49003).
   --help: Print this dialogue.
   EOF

   return $help_text;
}

1;
