#!/bin/perl

use strict;
use warnings;
use File::Copy;
use File::Glob ':bsd_glob';
use Fcntl qw( SEEK_SET SEEK_END );


sub find_game_resources {
    
    my $sr_resources;
    my $op_params = shift;
    
    die "Invalid game selection. Either of returns|dragonfall|hongkong must be specified.\n" 
    unless $op_params->{edition} =~ s/^(returns|dragonfall|hongkong)$/\u$1/i;
    
    $op_params->{edition} =~ s/Hongkong/Hong\ Kong/;

    PATH_TRIAL: foreach my $path_expr (@{$op_params->{install_dirs}{$op_params->{platform}}}) {

        foreach my $path (bsd_glob("$path_expr")) {

            if ($path =~ /Shadowrun\s$op_params->{edition}/) {
           
	        $sr_resources = bsd_glob("$path/*_Data");
                last PATH_TRIAL;
                
            }
       
        }

    }
    
    die "Unable to locate Shadowrun $op_params->{edition} game assets.\n" 
    unless $sr_resources && -d $sr_resources; 
    
    print "Found: $sr_resources\n";
    return $sr_resources;

}


sub asset_dump {

    my $delimiter = qr/\x00*\x02\x00{3}\x0E\00{7}\x02\x00{3}/;
    my $op_params = $_[0];
    my $assets_content = $_[1];
    my $sound_meta_start = $_[2];
    my @track_list;
    
    print "Parsing resources.assets...\n";

    while ($assets_content =~ /([\w-]+)$delimiter/g) {

           my($tracksize, $resS_offset) = unpack("V2", substr($assets_content, $+[0], 8));
           my $size_offset = $sound_meta_start + $+[0];

	   print "\n$1\n", "-"x45, "\nSize: $tracksize\n",
	   "Size data offset: $size_offset\nTrack resS offset: $resS_offset\n" 
	   if $op_params->{verbose} == 1;
	   
	   push(@track_list, {"name" => $1, "size_offset" => $size_offset, "size" => $tracksize, "track_offset" => $resS_offset});

    }
    
    print "\n" if $op_params->{verbose} == 1;
    return @track_list;
}


sub resS_dump {

    my $ogg_first_page = qr/OggS\x00\x02/;
    my $op_params = $_[0];
    my $resS_content = $_[1];
    my $track_num = 0;
    my @offset_list;

    print "Parsing resources.assets.resS replacment file...\n";
    print "\n" if $op_params->{verbose} == 1;

    while ($resS_content =~ /$ogg_first_page/g) {

	 print "Track ", ++$track_num, " offset: $-[0]\n" if $op_params->{verbose} == 1;
         push(@offset_list, $-[0]);

    }

    print "\n" if $op_params->{verbose} == 1;
    return @offset_list;
}


sub asset_update {

   my $op_params = $_[0];
   my $current_tracklist = $_[1]->{"track_list"};
   my $new_track_offsets = $_[1]->{"new_offsets"};
   my $resS_end = $_[1]->{"resS_end"};
   my $assets_file = $_[2];
 
   die "Number of replacement offsets does not match original track number.\n" 
   unless @{$new_track_offsets} == @{$current_tracklist};  
   
   print "Remapping offset and size values in resources.assets...\n";

   push (@{$new_track_offsets}, $resS_end); 

   foreach my $track (@{$current_tracklist}) {

       $track->{"track_offset"} = shift(@{$new_track_offsets});
       $track->{"size"} = $new_track_offsets->[0] - $track->{"track_offset"};

       print "\n$track->{qq/name/}\n", "-"x45, "\nNew size: $track->{qq/size/}\n",
       "New resS offset: $track->{qq/track_offset/}\n" 
       if $op_params->{verbose} == 1;
       
       seek($assets_file, $track->{"size_offset"}, SEEK_SET);
       print $assets_file pack("VV", $track->{"size"}, $track->{"track_offset"}); 

   }

   print "\n" if $op_params->{verbose} == 1;

}


sub swap_music_files {

   my $op_params = shift;
   my $sound_meta_start = $op_params->{meta_offsets}{$op_params->{edition}};
   my %offset_meta;


   open(my $assets_file, "+<:raw", "$op_params->{sr_resources}/resources.assets") 
   or die "resources.assets file missing or access restricted.\n";

   seek($assets_file, $sound_meta_start, SEEK_SET);
   my $assets_content = do { local $/ = undef; <$assets_file>; };
   $offset_meta{"track_list"} = [ asset_dump($op_params, $assets_content, $sound_meta_start) ];

   open(my $new_resS, "<:raw", "$op_params->{new_resS_file}") 
   or die "Unable to open resources.assets.resS replacment.\n";

   my $new_resS_content = do { local $/ = undef; <$new_resS>; };
   seek($new_resS, 0, SEEK_END);
   $offset_meta{"resS_end"} = tell($new_resS); 
   close($new_resS);
   $offset_meta{"new_offsets"} = [ resS_dump($op_params, $new_resS_content) ];

   open(my $current_resS, ">:raw", "$op_params->{sr_resources}/resources.assets.resS") 
   or die "Unable to update resources.assets.resS.\n";
   
   print $current_resS $new_resS_content;
   close($current_resS);

   asset_update($op_params, \%offset_meta, $assets_file);

   close($assets_file);

}


sub music_replace {

   my $op_params = shift;
   
   die "You must give a valid path to a new resources.assets.resS file.\n" 
   unless $op_params->{new_resS_file} 
   && -s bsd_glob("$op_params->{new_resS_file}");
 
   $op_params->{sr_resources} = find_game_resources($op_params); 

   while (-e "$op_params->{sr_resources}/resources.assets.resS.bak") {

       print "A backup file for resources.assets.resS is already present. ", 
       "Are you sure you want to continue with the replacement? (y/n) "; 

       chomp(my $user_choice = <STDIN>);

       last if $user_choice =~ /y/i;
       exit 0 if $user_choice =~ /n/i;
       print "\n";

   }

   move("$op_params->{sr_resources}/resources.assets.resS", "$op_params->{sr_resources}/resources.assets.resS.bak") 
   or die "Backup file creation failed.\n";

   print "Created backup: $op_params->{sr_resources}/resources.assets.resS.bak\n";  

   swap_music_files($op_params);

   print "Done\n";

}


sub music_restore {

   my $op_params = shift;

   $op_params->{sr_resources} = find_game_resources($op_params); 
   $op_params->{new_resS_file} = "$op_params->{sr_resources}/resources.assets.resS.bak";

   die "No backup file found in $op_params->{sr_resources}\n" unless -s "$op_params->{new_resS_file}";

   swap_music_files($op_params);

   unlink "$op_params->{sr_resources}/resources.assets.resS.bak" 
   or warn "Failed to delete backup file.\n";

   print "Done\n";

}


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
   my %op_params = (
                    
          edition => "Returns",
          new_resS_file => undef,
          verbose => 0,

	  #Some OS specific glob patterns that are used by the script to locate the Shadowrun games. 
          install_dirs => { 
		                
		   linux => [
                              
			 "~/.local/share/Steam/steamapps/common/Shadowrun*",
                         "~/.steam/steam/SteamApps/common/Shadowrun*",
                         "~/{[Ss]team,[Gg]ames,GOG}/{,[Ss]team/,GOG/,[Ss]hadowrun/}Shadowrun*",
                         "~/.wine{,32,64,_steam,_shadowrun}/drive_c/{GOG Games,Program Files{, (x86)}/Steam/steamapps/common}/Shadowrun*"

		            ],                

                   windows => [
                                                 
	                 "c:/Program Files{, (x86)}/{,Steam/steamapps/common/}Shadowrun*",
		         "c:/GOG Games/Shadowrun*"
 
		              ],

                   mac => [ 
		   
		         "~/Library/Application Support/Steam/SteamApps/common/Shadowrun*"
                                                    
			  ]
                              
			},

         #Hardcoded offsets for the respective Shadowrun game at which 
         #the script will start loading the resources.assets file into memory.
         #Its size varies between the games, with that of Shadowrun Returns being around 600 Megabytes 
         #and that of Hong Kong almost 2 Gigabytes. 
         #In all cases, slurping it whole might impose a noticeable penalty on performance.
         meta_offsets => {
                                  
		       Returns => 624000000,
		       Dragonfall => 1794000000,
		       "Hong Kong" => 2002710000
                                         
		         }

                   );


   #We try to determine the OS by checking what platform the Perl
   #implementation was compiled for. Linux is the fallback value.
   if ($^O eq 'MSWin32') { $op_params{platform} = "windows"; }

   elsif ($^O eq 'darwin') { $op_params{platform} = "mac"; }

   else { $op_params{platform} = "linux"; }
	   

   until (@ARGV == 0) {

       if ($ARGV[0] =~ /-*help/i) { help_dialogue; exit 0; }

       elsif ($ARGV[0] =~ /-swap/i) { 
                                      $operation = 1; 
                                      get_option();				    
                                      chomp($op_params{new_resS_file} = $ARGV[0]);
				    }

       elsif ($ARGV[0] =~ /-restore/i) { $operation = 2; }

       elsif ($ARGV[0] =~ /-i/i) { 
                                   get_option();
                                   chomp($ARGV[0]); 
				   $ARGV[0] =~ s/\/$//;
				   unshift(@{$op_params{install_dirs}{$op_params{platform}}}, $ARGV[0]); 
				 }

       elsif ($ARGV[0] =~ /-e/i) { get_option(); chomp($op_params{edition} = "\L$ARGV[0]"); }

       elsif ($ARGV[0] =~ /-v/i) { $op_params{verbose} = 1; }

       else { die "Unsupported commandline parameter. Type --help for more info...\n";}

   shift;

   }

   if ($operation == 1) { music_replace(\%op_params); }

   elsif ($operation == 2) { music_restore(\%op_params); }

   else { die "One of the operation modes (-swap/-restore) must be specified.\n"; }

}  

else { help_dialogue; }
