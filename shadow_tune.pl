#!/bin/perl

use lib '.';
use shadow_dump;

sub get_option {
    
   shift @ARGV;
   die "Error, option without a value detected.\n" unless @ARGV != 0 && $ARGV[0] !~ /-+\w/; 

}


sub help_dialogue {
 
 print "-Swap music files:\n",
       "$0 -swap <path-to-new-resources.assets.resS-file> [-e returns|dragonfall|hongkong ] [-i <path-to-shadowrun-install-folder>] [-v]\n",
       "The selected resources.assets.resS file should contain the new music tracks (in Ogg Vorbis format).\n",
       "The script will make a backup copy of the original resources.assets.resS that can later be used for the restore operation.\n\n",
       "-Restore original music:\n",
       "$0 -restore [-e returns|dragonfall|hongkong ] [-i <path-to-shadowrun-install-folder>] [-v]\n",
       "This operation will fail if the script can't locate the backup copy.\n\n",
}


if ( @ARGV != 0) {

   my $operation = 0;

   my $game = shadow_dump->new("Returns", 0);    
   $game->detect_platform();	   

   until (@ARGV == 0) {

       if ($ARGV[0] =~ /-*help/i) { help_dialogue; exit 0; }

       elsif ($ARGV[0] =~ /-swap/i) { 
                                      $operation = 1; 
                                      get_option();				    
				      chomp($ARGV[0]);
                                      $game->set_resS_file($ARGV[0]);
				    }

       elsif ($ARGV[0] =~ /-restore/i) { $operation = 2; }

       elsif ($ARGV[0] =~ /-i/i) { 
                                   get_option();
                                   chomp($ARGV[0]); 
				   $ARGV[0] =~ s/\/$//;
				   $game->add_game_path($ARGV[0]); 
				 }

       elsif ($ARGV[0] =~ /-e/i) { get_option(); chomp($ARGV[0]); $game->set_edition($ARGV[0]); }

       elsif ($ARGV[0] =~ /-v/i) { $game->set_verbose(1); }

       else { die "Unsupported commandline parameter. Type --help for more info...\n";}

   shift;

   }


   if ($operation == 1) { $game->music_replace(); }

   elsif ($operation == 2) { $game->music_restore(); }

   else { die "One of the operation modes (-swap/-restore) must be specified.\n"; }

}  

else { help_dialogue; }
