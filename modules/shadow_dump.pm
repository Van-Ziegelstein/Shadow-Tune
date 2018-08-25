package shadow_dump;

use strict;
use warnings;
use File::Copy;
use File::Glob ':bsd_glob';
use Fcntl qw( SEEK_SET SEEK_END );

sub new {

    my $class = shift;

    return bless { 
                   edition => shift,
		   verbose => shift,
		   platform => "linux",

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
                 
                 }, $class;


}


sub detect_platform {

   my $self = shift;

   #We try to determine the OS by checking what platform the Perl
   #implementation was compiled for. Linux is the fallback value.
   if ($^O eq 'MSWin32') { $self->{platform} = "windows"; }

   elsif ($^O eq 'darwin') { $self->{platform} = "mac"; }

   else { $self->{platform} = "linux"; }

}


sub set_resS_file {
   
   my ($self, $resS_file) = @_;
   $self->{new_resS_file} = bsd_glob($resS_file) if defined $resS_file;

}


sub get_resS_file {

   my $self = shift;
   return $self->{new_resS_file};
}


sub set_edition {
   
   my ($self, $edition) = @_;
   $self->{edition} = "\L$edition" if defined $edition;

}


sub get_edition {

   my $self = shift;
   return $self->{edition};
}


sub set_verbose {
   
   my ($self, $verbose) = @_;
   $self->{verbose} = $verbose if defined $verbose;

}


sub get_verbose {

   my $self = shift;
   return $self->{verbose};
}


sub add_game_path {

    my ($self, $path) = @_;
    unshift(@{$self->{install_dirs}{$self->{platform}}}, $path) if defined $path;

}


sub find_game {
    
    my $self = shift;
    
    die "Invalid game selection. Either of returns|dragonfall|hongkong must be specified.\n" 
    unless $self->{edition} =~ s/^(returns|dragonfall|hongkong)$/\u$1/i;
    
    $self->{edition} =~ s/Hongkong/Hong\ Kong/;

    PATH_TRIAL: foreach my $path_expr (@{$self->{install_dirs}{$self->{platform}}}) {

        foreach my $path (bsd_glob("$path_expr")) {

            if ($path =~ /Shadowrun\s$self->{edition}/) {
           
	        $self->{sr_resources} = bsd_glob("$path/*_Data");
                last PATH_TRIAL;
                
            }
       
        }

    }
    
    die "Unable to locate Shadowrun $self->{edition} game assets.\n" 
    unless defined $self->{sr_resources} && -d $self->{sr_resources}; 
    
    print "Found: $self->{sr_resources}\n\n";

}


sub __asset_dump {

    my $delimiter = qr/\x00*\x02\x00{3}\x0E\x00{7}\x02\x00{3}/;
    my $self = shift;
    my ($assets_content, $sound_meta_start) = @_;
    my @track_list;
    
    print ">>> Parsed resources.assets <<<\n";

    while ($assets_content =~ /([\w-]+)$delimiter/g) {

           my($tracksize, $resS_offset) = unpack("V2", substr($assets_content, $+[0], 8));
           my $size_offset = $sound_meta_start + $+[0];

	   print "\n$1\n", "-"x45, "\nSize: $tracksize\n",
	   "Size data offset: $size_offset\nTrack resS offset: $resS_offset\n" 
	   if $self->{verbose} == 1;
	   
	   push(@track_list, {"name" => $1, "size_offset" => $size_offset, "size" => $tracksize, "track_offset" => $resS_offset});

    }
    
    print "\n" if $self->{verbose} == 1;
    return @track_list;
}


sub __resS_dump {

    my $ogg_first_page = qr/OggS\x00\x02/;
    my $self = shift;
    my ($resS_content, $track_num) = @_;
    my @offset_list;

    print ">>> Parsed resources.assets.resS replacment file <<<\n";
    print "\n" if $self->{verbose} == 1;

    while ($resS_content =~ /$ogg_first_page/g) {

	 print "Track ", ++$track_num, " offset: $-[0]\n" if $self->{verbose} == 1;
         push(@offset_list, $-[0]);

    }

    print "\n" if $self->{verbose} == 1;
    return @offset_list;
}


sub __asset_update {

   my $self = shift;
   my $current_tracklist = $_[0]->{"track_list"};
   my $new_track_offsets = $_[0]->{"new_offsets"};
   my $resS_end = $_[0]->{"resS_end"};
   my $assets_file = $_[1];
 
   die "Number of replacement offsets does not match original track number.\n" 
   unless @{$new_track_offsets} == @{$current_tracklist};  
   
   print ">>> Remapped offset and size values in resources.assets <<<\n";

   push (@{$new_track_offsets}, $resS_end); 

   foreach my $track (@{$current_tracklist}) {

       $track->{"track_offset"} = shift(@{$new_track_offsets});
       $track->{"size"} = $new_track_offsets->[0] - $track->{"track_offset"};

       print "\n$track->{qq/name/}\n", "-"x45, "\nNew size: $track->{qq/size/}\n",
       "New resS offset: $track->{qq/track_offset/}\n" 
       if $self->{verbose} == 1;
       
       seek($assets_file, $track->{"size_offset"}, SEEK_SET);
       print $assets_file pack("VV", $track->{"size"}, $track->{"track_offset"}); 

   }

   print "\n" if $self->{verbose} == 1;

}


sub __swap_music_files {

   my $self = shift;
   my $sound_meta_start = $self->{meta_offsets}{$self->{edition}};
   my %offset_meta;


   open(my $assets_file, "+<:raw", "$self->{sr_resources}/resources.assets") 
   or die "resources.assets file missing or access restricted.\n";

   seek($assets_file, $sound_meta_start, SEEK_SET);
   my $assets_content = do { local $/ = undef; <$assets_file>; };
   $offset_meta{"track_list"} = [ $self->__asset_dump($assets_content, $sound_meta_start) ];

   open(my $new_resS, "<:raw", "$self->{new_resS_file}") 
   or die "Unable to open resources.assets.resS replacement.\n";

   my $new_resS_content = do { local $/ = undef; <$new_resS>; };
   seek($new_resS, 0, SEEK_END);
   $offset_meta{"resS_end"} = tell($new_resS); 
   close($new_resS);
   $offset_meta{"new_offsets"} = [ $self->__resS_dump($new_resS_content) ];

   open(my $current_resS, ">:raw", "$self->{sr_resources}/resources.assets.resS") 
   or die "Unable to update resources.assets.resS.\n";
   
   print $current_resS $new_resS_content;
   close($current_resS);

   $self->__asset_update(\%offset_meta, $assets_file);

   close($assets_file);

}


sub music_replace {

   my $self = shift;
   
   die "You must give a valid path to a new resources.assets.resS file.\n" 
   unless defined $self->{new_resS_file} 
   && -s $self->{new_resS_file};

   print "Found replacement file: $self->{new_resS_file}\n\n"; 

   $self->find_game(); 

   die "A backup file is already present.\n" if -e "$self->{sr_resources}/resources.assets.resS.bak";


   move("$self->{sr_resources}/resources.assets.resS", "$self->{sr_resources}/resources.assets.resS.bak") 
   or die "Backup file creation failed.\n";

   print "Created backup: $self->{sr_resources}/resources.assets.resS.bak\n\n";  

   $self->__swap_music_files();

   print "Done\n";

}


sub music_restore {

   my $self = shift;

   $self->find_game(); 
   $self->set_resS_file("$self->{sr_resources}/resources.assets.resS.bak");

   die "No backup file found in $self->{sr_resources}\n\n" unless -s "$self->{new_resS_file}";

   print "Found backup file: $self->{new_resS_file}\n\n";

   $self->__swap_music_files();

   unlink "$self->{sr_resources}/resources.assets.resS.bak" 
   or warn "Failed to delete backup file.\n";

   print "Done\n";

}

1;
