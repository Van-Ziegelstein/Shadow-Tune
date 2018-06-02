#!/bin/perl


use strict;
use warnings;
use File::Copy;
use Fcntl qw( SEEK_SET SEEK_END );

#A hard coded offset including some safe space at which the script will start loading the content of the resources.assets file. Since the entire file is about 2G, slurping it whole would be excessive.
my $sound_meta_start = 2002710000;


#The predefined paths where the script searches for the Shadowrun Hong Kong install.
my @install_dirs = (

   "~/.local/share/Steam/steamapps/common/Shadowrun Hong Kong",
   "~/.steam/steam/SteamApps/common/Shadowrun Hong Kong",
   "~/{Steam,Games,GOG}/{,Steam/,GOG/,Shadowrun/}Shadowrun Hong Kong",
   "~/{steam,games,gog}/{,steam/,gog/,shadowrun/}Shadowrun Hong Kong",
   "~/.wine{,32,64,_steam,_shadowrun}/drive_c/{GOG Games,Program Files/Steam/steamapps/common}/Shadowrun Hong Kong"
   
);


sub find_game_resources {

    my $srhk_resources;

    PATH_TRIAL: foreach my $path_expr (@install_dirs) {

        foreach my $path (glob(qq/"$path_expr"/)) {
	    
            if (-d ($path .= "/SRHK_Data")) {
           
                $srhk_resources = $path;
                last PATH_TRIAL;
                
            }
       
        }

    }
    
    die "Unable to locate Shadowrun Hong Kong game assets.\n" unless $srhk_resources; 
    print "Found: $srhk_resources\n";
    return $srhk_resources;

}


sub asset_dump {

    my $delimiter = qr/\x00*\x02\x00{3}\x0E\00{7}\x02\x00{3}/;
    my $assets_content = $_[0];
    my $verbose = $_[1];
    my @track_list;
    
    print "Parsing resources.assets...\n";

    while ($assets_content =~ /(HongKong-[\w-]+|TESTSTINGER)$delimiter/g) {

           my($tracksize, $resS_offset) = unpack("V2", substr($assets_content, $+[0], 8));
           my $size_offset = $sound_meta_start + $+[0];

	   print "\n$1\n", "-"x45, "\nSize: $tracksize\nSize data offset: $size_offset\nTrack resS offset: $resS_offset\n" if $verbose == 1;
	   
	   push(@track_list, {"name" => $1, "size_offset" => $size_offset, "size" => $tracksize, "track_offset" => $resS_offset});

    }
    
    print "\n" if $verbose == 1;
    return @track_list;
}


sub resS_dump {

    my $ogg_first_page = qr/OggS\x00\x02/;
    my $resS_content = $_[0];
    my $verbose = $_[1];
    my $track_num = 0;
    my @offset_list;

    print "Parsing resources.assets.reS replacment file...\n";
    print "\n" if $verbose == 1;

    while ($resS_content =~ /$ogg_first_page/g) {

	   print "Track ", ++$track_num, " offset: $-[0]\n" if $verbose == 1;
           push(@offset_list, $-[0]);

    }

    print "\n" if $verbose == 1;
    return @offset_list;
}


sub asset_update {

   my $current_tracklist = $_[0]->{"track_list"};
   my $new_track_offsets = $_[0]->{"new_offsets"};
   my $resS_end = $_[0]->{"resS_end"};
   my $assets_file = $_[1];
   my $verbose = $_[2];
  
   die "Number of replacement offsets does not match original track number.\n" unless @{$new_track_offsets} == @{$current_tracklist};  

   print "Remapping offset and size values in resources.assets...\n";

   push (@{$new_track_offsets}, $resS_end); 

   foreach my $track (@{$current_tracklist}) {

       $track->{"track_offset"} = shift(@{$new_track_offsets});
       $track->{"size"} = $new_track_offsets->[0] - $track->{"track_offset"};

       print "\n$track->{qq/name/}\n", "-"x45, "\nNew size: $track->{qq/size/}\nNew resS offset: $track->{qq/track_offset/}\n" if $verbose == 1;
       
       seek($assets_file, $track->{"size_offset"}, SEEK_SET);
       print $assets_file pack("VV", $track->{"size"}, $track->{"track_offset"}); 

   }

   print "\n" if $verbose == 1;

}


sub swap_music_files {

   my $srhk_resources = $_[0];
   my $replacement_resS_file = $_[1];
   my $verbose = $_[2];
   my %offset_meta;


   open(my $assets_file, "+<:raw", "$srhk_resources/resources.assets") or die "resources.assets file missing or access restricted.\n";

   seek($assets_file, $sound_meta_start, SEEK_SET);
   my $assets_content = do { local $/ = undef; <$assets_file>; };
   $offset_meta{"track_list"} = [ asset_dump($assets_content, $verbose) ];
    
   open(my $new_resS, "<:raw", "$replacement_resS_file") or die "Unable to open resources.assets.resS replacment.\n";

   my $new_resS_content = do { local $/ = undef; <$new_resS>; };
   seek($new_resS, 0, SEEK_END);
   $offset_meta{"resS_end"} = tell($new_resS); 
   close($new_resS);
   $offset_meta{"new_offsets"} = [ resS_dump($new_resS_content, $verbose) ];
   
   open(my $current_resS, ">", "$srhk_resources/resources.assets.resS") or die "Unable to update resources.assets.resS.\n";
   print $current_resS $new_resS_content;
   close($current_resS);

   asset_update(\%offset_meta, $assets_file, $verbose);

   close($assets_file);

}


sub music_replace {

   my $srhk_resources;
   my $verbose = $_[1];
   my $new_resS_file = $_[0];

   die "You must give a valid path to a new resources.assets.reS file.\n" unless $new_resS_file && -s glob(qq/"$new_resS_file"/);

   $srhk_resources = find_game_resources(); 

   while (-e "$srhk_resources/resources.assets.resS.bak") {

        print "A backup file for resources.assets.resS is already present. Are you sure you want to continue with the replacement? (y/n) "; 

        chomp(my $user_choice = <STDIN>);

	last if $user_choice =~ /y/i;
	exit 0 if $user_choice =~ /n/i;
	print "\n";

   }

   move("$srhk_resources/resources.assets.resS", "$srhk_resources/resources.assets.resS.bak") or die "Backup file creation failed.\n";
   
   print "Created backup: $srhk_resources/resources.assets.resS.bak\n";
   
   swap_music_files($srhk_resources, $new_resS_file, $verbose);

   print "Done\n";

}


sub music_restore {

   my $srhk_resources;
   my $verbose = $_[0];

   $srhk_resources = find_game_resources(); 

   die "No backup file found in $srhk_resources\n" unless -s "$srhk_resources/resources.assets.resS.bak";

   swap_music_files($srhk_resources, "$srhk_resources/resources.assets.resS.bak", $verbose);

   unlink "$srhk_resources/resources.assets.resS.bak" or warn "Failed to delete backup file.\n";

   print "Done\n";

}


sub help_dialogue {
 
 print "\nThis is a small tool for modders/users who wish to tinker with Shadowrun Hong Kong's sound files.\n",
       "Its main purpose is to automate the replacement of the vanilla soundtrack.\n",
       "The script has two operation modes:\n\n",
       "swap: replace the existing resources.assets.resS file with a new one and update the metadata in resources.assets. The format of the command is:\n",
       "shadow_tune.pl -swap -n <path-to-new-resources.assets.reS-file> [-i <path-to-shadowrun-install-folder>] [-v]\n",
       "The file provided via the -n option should be the new resources.assets.reS file containing the music tracks (in ogg vorbis format) that the user wishes to use.\n",
       "Before replacing the original, the script will make a backup copy of the resources.assets.reS file that can later be used for the restore operation.\n\n",
       "restore: revert back to the state prior to the sound modification. The format of the command is:\n",
       "shadow_tune.pl -restore [-i <path-to-shadowrun-install-folder>] [-v]\n",
       "This operation will fail if the script can't locate the backup copy mentioned above.\n\n",
       "With both modes, the script will try to locate the directory where Shadowrun was installed.\n",
       "In case this process fails, there's the optional -i commandline parameter, which lets you manually set the path. Note that this should just be the path to the root directory of the installation.\n\n",
       "More verbose output can be obtained via the -v parameter.\n\n",
       "And of course --help prints this stuff.\n\n";
}



if ( @ARGV != 0) {

   my $new_resS_file;
   my $verbose = 0;
   my $operation = 0;

   until (@ARGV == 0) {

       if ($ARGV[0] =~ /--help/i) { help_dialogue; exit 0; }

       elsif ($ARGV[0] =~ /-swap/i) { $operation = 1; }

       elsif ($ARGV[0] =~ /-restore/i) { $operation = 2; }

       elsif ($ARGV[0] =~ /-n/i) { shift; chomp($new_resS_file = $ARGV[0]); }

       elsif ($ARGV[0] =~ /-i/i) { shift; 
                                   chomp($ARGV[0]); 
				   $ARGV[0] =~ s/\/$//;
				   unshift(@install_dirs, $ARGV[0]); 
				 }

       elsif ($ARGV[0] =~ /-v/i) { $verbose = 1; }

       else { die "That option is unsupported. Type --help for more info...\n";}

   shift;

   }

   if ($operation == 1) { music_replace($new_resS_file, $verbose); }

   elsif ($operation == 2) { music_restore($verbose); }

   else { die "One of the operation modes (-swap/-restore) must be specified.\n"; }

}  

else { help_dialogue; }
