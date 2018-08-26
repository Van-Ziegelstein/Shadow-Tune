#!/bin/perl

use lib 'modules';
use shadow_dump;
use shadow_browse;
use shadow_tools qw(get_option help_screen);


use strict;
use warnings;
use Socket qw(:DEFAULT :crlf);
use Encode();
use POSIX();



sub server_setup {

 my $port = shift;
 my $localhost = gethostbyname("localhost") or die "Could not look up localhost.\n";

 socket(my $sockfd, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
 setsockopt($sockfd, SOL_SOCKET, SO_REUSEADDR, 1);

 bind ($sockfd, sockaddr_in($port, $localhost)) 
 or die "Failed to bind to socket!\n";
 listen($sockfd, 5);
 
 
 while (1) {
 
  
    if (my $client_addr = accept(my $cl_sockfd, $sockfd)) {
  
       my @req_params;
       my $l_count = 0;

       local($/) = LF;

       while (<$cl_sockfd>) {

           s/$CR?$LF/\n/;
           last if /^\n/ || $l_count == 25;      
               
           push(@req_params, $_);
           $l_count++;
                  
       }
  
       my %tagged_params = request_parser($cl_sockfd, \@req_params); 
       
       print $cl_sockfd "HTTP/1.1 400 Bad Request", $CRLF x 2 unless 
       defined $tagged_params{method} && 
       $tagged_params{bad_input} == 0;


       if ($tagged_params{method} eq "GET") {  
                   
             if ($tagged_params{url_path} eq "/help") { content_display($cl_sockfd, help_screen()); }

             else { content_display($cl_sockfd, fetch_page()); }
       }
       
       elsif ($tagged_params{method} eq "POST") {
             
	     if ($tagged_params{length_exceeded} == 1) {
                
		print $cl_sockfd "HTTP/1.1 413 Payload Too Large", $CRLF x 2;

	     }
             
	     elsif ($tagged_params{length_missing} == 1) {
                
		print $cl_sockfd "HTTP/1.1 411 Length Required", $CRLF x 2;

	     }

	     else {

                my $back_pid = fork();
		die "Backend fork failed.\n" unless defined $back_pid;

                if ($back_pid == 0) {
		  
		   my $game = shadow_dump->new("Returns", 0);    
                   $game->add_game_path($tagged_params{sr_install}) if defined $tagged_params{sr_install};

                   $game->set_resS_file($tagged_params{new_resS}) if defined $tagged_params{new_resS};

	           $game->set_edition($tagged_params{edition}) if defined $tagged_params{edition};

	           $game->set_verbose($tagged_params{verbose}) if defined $tagged_params{verbose};

		 
                   open(STDOUT, ">&=", $cl_sockfd);
                   $| = 1;
                   open(STDERR, ">&STDOUT") or die "Can't re-open STDERR\n";

	           if (defined $tagged_params{action} && $tagged_params{action} eq "swap") { $game->music_replace(); } 

                   elsif (defined $tagged_params{action} && $tagged_params{action} eq "restore") { $game->music_restore(); } 

	           else { print "Invalid action.\n"; }
                      
		   exit;

		 }

		 wait();

             }       

       }

       CLOSE_CONNECTION: close($cl_sockfd);
       
    }
    
 }
 
 close($sockfd);

}


sub request_parser {

  my %req_params = (bad_input => 0, length_exceeded => 0, length_missing => 0);
  my $cl_sock = shift;
  my @form_fields = ("sr_install", "new_resS", "action", "edition", "verbose");

  foreach my $element (@{$_[0]}) {
  
     if ($element =~ /(\D+)\s(\/.*)\sHTTP\/[\d\.]+/) { $req_params{method} = $1; $req_params{url_path} = $2; }
  
     $req_params{content_length} = $1 if $element =~ /Content-Length:\s(\d+)/;
     
  }


  if (defined $req_params{method} && $req_params{method} eq "POST") { 

     if (defined $req_params{content_length}) {
  
         if ($req_params{content_length} <= 2000 ) { 
     
             read($cl_sock, $req_params{query}, $req_params{content_length});

	     $req_params{bad_input} = 1 unless $req_params{query} =~ /^[\w\+&=\\\/]+$/;
	     $req_params{query} =~ s/\+/ /g;

             foreach my $field (@form_fields) {

                 $req_params{$field} = $1 if $req_params{query} =~ /$field=(.*?)(&|$)/;
	     }

         }

         else { $req_params{length_exceeded} = 1; }

     }

     else { $req_params{length_missing} = 1; }
     
  }

  return %req_params;

}


sub fetch_page {

  my $page_content;

  open(my $page_fd, "<", "page_content/landing.html") or die "Can't open page document.\n";

  while (<$page_fd>) { $page_content .= $_; }

  close($page_fd);
  return $page_content;  
  
}


sub content_display {

   my $cl_sock = shift;
   my $markup = shift;
   
   my $body_length = length(Encode::encode_utf8($markup)); 
   my $http_date =  POSIX::strftime("%a, %d %b %Y %R:%S GMT", gmtime);
   
   my $response_head = <<~"EOF";
   HTTP/1.1 200 OK
   Date: $http_date
   Server: Eye of Terror
   Content-Type: text/html; charset=UTF-8
   Content-Length: $body_length
   Connection: close
   EOF

   $response_head =~ s/\n/$CRLF/g;
   
   select ($cl_sock);
   $| = 1;
   print $response_head, $CRLF, $markup;
   
   select (STDOUT);
   
}



die "This platform seems to be unsupported.\n" unless 
$^O eq "linux" ||
$^O eq "MSWin32" ||
$^O eq "darwin";

my $port = 49003;

until (@ARGV == 0) {

  if ($ARGV[0] =~ /-*help/i) { print help_screen(); exit 0; }

  elsif ($ARGV[0] =~ /-p/) { get_option(); chomp($port = $ARGV[0]); }

  shift;

}

my $browser = shadow_browse->new("http://localhost:$port");
print "Listening on port: $port\n";

my $serv_pid = fork();
die "Server fork failed\n" unless defined $serv_pid;

if ($serv_pid == 0) {

    print "Starting server daemon, pid = $$\n";
    server_setup($port);
}

$browser->start_browser();

