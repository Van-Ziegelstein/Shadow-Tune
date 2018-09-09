package shadow_tools;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(get_option help_screen);


sub get_option {
    
   shift @ARGV;
   die "Error, option without a value detected.\n" unless @ARGV != 0 && $ARGV[0] !~ /^-+[a-zA-Z-]+$/; 

}


sub help_screen {
 
   my $help_text = <<~"EOF"; 
   This is the gui version of Shadow Tune.
   Upon startup, the script will start a tiny
   server and attempt to locate the default browser.

   ---Startup tweaking---

   Accepted commandline options:

      -p: Specify a port to listen on (default 49003).
      --help: Print this dialogue.


   ---Interface navigation---
      
      Change the parameters to fit the operation 
      you want to perform. 
      
      The field concerning the Shadowrun game folder 
      can be left empty. In that case the program 
      will try to locate the game directory using a set
      of hardcoded paths.

      The "verbose" option is optional as well and can be toggled
      to get a more detailed output log.

      Once all is set, hit "Go" to carry out the sound modification.

      Important: Currently the script will refuse to replace 
      the soundtrack if a backup copy of resources.assets.resS
      is found. Revert back to the unmodified state with the "restore" 
      option or manually delete the backup file if you really don't
      care about the original game files.

      Even more important: After you're done, don't forget to hit the
      "back to the shadows" button to terminate the program. Otherwise
      it will (under certain conditions) continue to wait for commands
      even after the browser is closed.
   EOF

   return $help_text;
}

1;
