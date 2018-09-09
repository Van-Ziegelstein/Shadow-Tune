#!/bin/perl

use lib 'modules';
use shadow_dump;
use shadow_browse;
use shadow_tools qw(get_option help_screen);


use strict;
use warnings;
use Socket qw(:DEFAULT :crlf);
use Encode();
use Digest::MD5 qw(md5_hex);
use Sys::Hostname;


sub server_setup {

  my ($port, $session_key) = @_;
  my $localhost = gethostbyname("localhost") or die "Could not look up localhost.\n";
  my $cl_addr;

  socket(my $serv_sock, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
  setsockopt($serv_sock, SOL_SOCKET, SO_REUSEADDR, 1);

  bind ($serv_sock, sockaddr_in($port, $localhost)) 
  or die "Failed to bind to socket!\n";
  listen($serv_sock, 5);


  print "Server daemon initialized on port $port\n",
        "Key: $session_key\n\n";
 
  while ($cl_addr = accept(my $cl_sock, $serv_sock)) {
 
        my @req_params;
        my $l_count = 0;
	my $cl_ip = unpack_sockaddr_in($cl_addr);

	print ">>> New connection from " . inet_ntoa($cl_ip) . " <<<\n\n",
	      "---Request header---\n";

        local($/) = LF;

        while (<$cl_sock>) {

              s/$CR?$LF/\n/;
              last if /^\n/ || $l_count == 30;      
               
              push(@req_params, $_);
	      print;
              $l_count++;
                  
        }

	print "---End header---\n\n";
  
        my %tagged_params = request_parser($cl_sock, \@req_params); 
       
        if (! $tagged_params{method} || $tagged_params{bad_input} == 1) {

	       print "Malformed header or request body.\n\n";

               serv_respond($cl_sock, "HTTP/1.1 400 Bad Request", "Bad input fields.\n");
        }        

        elsif ($tagged_params{method} eq "GET") {  
                   
              if ($tagged_params{url_path} eq "/help") { serv_respond($cl_sock, "HTTP/1.1 200 OK", help_screen()); }

              elsif ($tagged_params{url_path} eq "/$session_key") { 
	     
	           serv_respond($cl_sock, "HTTP/1.1 200 OK", "<h1>Safe running, Chummer!</h1>");
	           close($cl_sock);
	           last;
	      }

              else { serv_respond($cl_sock, "HTTP/1.1 200 OK", fetch_page($session_key)); }

        }
       
        elsif ($tagged_params{method} eq "POST") {
             
	      if ($tagged_params{length_exceeded} == 1) {
                
		 print "Maximum payload length exceeded.\n\n";
	         serv_respond($cl_sock, "HTTP/1.1 413 Payload Too Large");

	      }
             
	      elsif ($tagged_params{length_missing} == 1) {
                
		    print "Payload length missing from header.\n\n";
		    serv_respond($cl_sock, "HTTP/1.1 411 Length Required");

	      }

	      else {

                   print "POST query: $tagged_params{query}\n\n";

                   my $back_pid = fork();
		   die "Backend fork failed.\n" unless defined $back_pid;

                   if ($back_pid == 0) {
		  
		      my $game = shadow_dump->new("Returns", 0);    
                      $game->add_game_path($tagged_params{sr_install}) if $tagged_params{sr_install};

                      $game->set_resS_file($tagged_params{new_resS}) if $tagged_params{new_resS};

	              $game->set_edition($tagged_params{edition}) if $tagged_params{edition};

	              $game->set_verbose($tagged_params{verbose}) if $tagged_params{verbose};

		 
		      local (*STDOUT, *STDERR);
		      my $recorded_out;

                      open(STDOUT, ">", \$recorded_out) or die "Can't redirect STDOUT to scalar.\n";
                      open(STDERR, ">&STDOUT") or die "Can't re-open STDERR.\n";

	              if ($tagged_params{action} && $tagged_params{action} eq "swap") { 
		      
		         local $@; 
			 eval { $game->music_replace(); 1; } or print $@; 

		      } 

                      elsif ($tagged_params{action} && $tagged_params{action} eq "restore") { 
		      
		            local $@; 
			    eval { $game->music_restore(); 1; } or print $@; 
			    
	              } 

	              else { print "Invalid action.\n"; }

		      serv_respond($cl_sock, "HTTP/1.1 200 OK", $recorded_out);
                      
		      exit 0;

		   }

		   wait();

             }       

       }

       else {

	    print "Unknown method requested.\n\n";
            serv_respond($cl_sock, "HTTP/1.1 405 Method Not Allowed", "This action is unsupported by this server.\n"); 
       }

       close($cl_sock);
       print ">>> closed <<<\n\n"; 
  }
 
  close($serv_sock);

}


sub request_parser {

  my %req_params = (bad_input => 0, length_exceeded => 0, length_missing => 0);
  my $cl_sock = shift;
  my @form_fields = ("sr_install", "new_resS", "action", "edition", "verbose");

  foreach my $element (@{$_[0]}) {
  
     if ($element =~ /(\D+)\s(\/.*)\sHTTP\/[\d\.]+/) { $req_params{method} = $1; $req_params{url_path} = $2; }
  
     $req_params{content_length} = $1 if $element =~ /Content-Length:\s(\d+)/;
     
  }


  if ($req_params{method} && $req_params{method} eq "POST") { 

     if ($req_params{content_length}) {
  
         if ($req_params{content_length} <= 700 ) { 
     
             read($cl_sock, $req_params{query}, $req_params{content_length});

	     $req_params{bad_input} = 1 unless $req_params{query} =~ /^[\w\+&=\\\/\.~:_-]+$/;
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

  my $session_key = shift;
  my $page_content;

  open(my $page_fd, "<", "page_content/landing.html") or die "Can't open page document.\n";

  while (<$page_fd>) { $page_content .= $_; }

  close($page_fd);

  $page_content =~ s/SESSIONKEY/$session_key/e;
  return $page_content;  
  
}


sub serv_respond {

   my ($cl_sock, $status, $markup) = @_;
   my $body_length;
   
   if ($markup) { $body_length = length(Encode::encode_utf8($markup)); } 
   
   else { $body_length = 0; } 

   my $response = <<~"EOF";
   $status
   Server: Shadow Tune
   Content-Type: text/html; charset=UTF-8
   Content-Length: $body_length
   Connection: close
   EOF

   #Convert platform specific newlines to the correct standard
   #and terminate the header. 
   $response =~ s/\n/$CRLF/g;
   $response .= $CRLF;

   #Add the content if present.
   $response .= $markup if $markup;
   
   select ($cl_sock);
   $| = 1;
   print $response;
   
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

die "Invalid port selection.\n" unless $port =~ /^\d+$/ &&
$port > 0 && $port <= 65535;

my $session_key = md5_hex(hostname() . rand(1000));
my $browser = shadow_browse->new("http://localhost:$port");

my $serv_pid = fork();
die "Server fork failed\n" unless defined $serv_pid;

if ($serv_pid == 0) {

    open(STDOUT, ">", "shadowlog.txt");
    open(STDERR, ">&STDOUT");

    server_setup($port, $session_key);

    print "Server terminated\n";
    exit 0;
}

my $findings = $browser->start_browser();
warn "Could not locate default browser.\n" unless defined $findings;

wait();


