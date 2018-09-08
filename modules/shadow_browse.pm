package shadow_browse;

use strict;
use warnings;
use Config;
use File::Spec::Functions qw(catfile);

sub new {

    my $class = shift;    

    return bless {

                  url => shift,
		  cmd => undef,

                  #A collection of OS specific browser startup commands.
		  #Likely to be expanded in the future.
		  os_cmds => {
                         
                       linux => [
                         
			   "x-www-browser",
			   "xdg-open",
			   "gnome-open",
			   "kfmclient",
			   "iceweasel",
                           "firefox",
			   "opera",
			   "google-chrome",
			   "chromium",
			   "chromium-browser"
		       ],

		       MSWin32 => [ "start" ],
		     
		       darwin => [ "/usr/bin/open" ]

		  },


        }, $class;    


}


sub start_browser() {

    my $self = shift;

    foreach my $cmd (@{$self->{os_cmds}{$^O}}) {

	    $self->{cmd} = $cmd;
            last if $^O eq "MSWin32" || $^O eq "darwin";
	    $self->{cmd} = __find_exe($self->{cmd});
	    last if $self->{cmd};


    }

    return unless $self->{cmd};

    return system($self->{cmd}, $self->{url});
}



sub __find_exe() {

    my $cmd = shift;

    for my $path (split(/:/, $ENV{PATH})) {
    next unless $path;
    my $exe = catfile($path, $cmd);
    return $exe if -x $exe;

  }

  return;

}


1;
