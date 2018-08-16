#!/bin/perl

use lib 'modules';
use shadow_dump;


use Socket;
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

       while ( my $line = <$cl_sockfd> ) {
                   
          last if $line =~ /^\r\n/m || $l_count == 25;      
               
          push(@req_params, $line);
          $l_count++;
                  
       }
  
       my %tagged_params = request_parser($cl_sockfd, \@req_params); 
       
       if ( $tagged_params{method} eq "unknown" ) {
       
          print $cl_sockfd "HTTP/1.1 400 Bad Request\r\n\r\n";
          goto CLOSE_CONNECTION;

       }

       elsif ($tagged_params{method} eq "GET") {  
                   
             if ($tagged_params{url_path} eq "/help") { content_display($cl_sockfd, help_screen()); }

             else { content_display($cl_sockfd, page_creator()); }
       }
       
       elsif ($tagged_params{method} eq "POST") {

             my $game = shadow_dump->new("Returns", 0);    
             $game->detect_platform();
                  
             $game->add_game_path($tagged_params{sr_install}) if defined $tagged_params{sr_install};

             $game->set_resS_file($tagged_params{new_resS}) if defined $tagged_params{new_resS};

	     $game->set_edition($tagged_params{edition}) if defined $tagged_params{edition};

	     $game->set_verbose($tagged_params{verbose}) if defined $tagged_params{verbose};

	     if (defined $tagged_params{action} && $tagged_params{action} == 1) { $game->music_replace(); } 

             elsif (defined $tagged_params{action} && $tagged_params{action} == 2) { $game->music_restore(); } 

       }       
  
       CLOSE_CONNECTION: close($cl_sockfd);
       
    }
    
 }
 
 close($sockfd);

}


sub request_parser {

  my %req_params;
  my $cl_sock = shift;
  my @form_fields = ("sr_install", "new_resS", "action", "edition", "verbose");

  foreach my $element (@{$_[0]}) {
  
     if ( $element =~ /(\D+)\s(\/.*)\sHTTP\/[\d\.]+/ ) { $req_params{method} = $1; $req_params{url_path} = $2; }
  
     $req_params{content_length} = $1 if $element =~ /Content-Length:\s(\d+)/;
     
  }

  $req_params{method} //= "Unknown";

  if ( $req_params{method} eq "POST" ) { 
  
     if ( defined $req_params{content_length} && $req_params{content_length} <= 500 ) { 
     
           read($cl_sock, $req_params{query}, $req_params{content_length});
     
     }
     
     else { $req_params{query} = "exceeded"; }
  

     if (defined $req_params{query} &&  $req_params{query} ne "exceeded") {

           $req_params{query} =~ s/\+/\s/g;

           foreach my $field (@form_fields) {

                   if ($req_params{query} =~ /$field=(.*?)&/ ) { $req_params{$field} = $1; }
	   }
          
     }
     
  }

  return %req_params;

}


sub page_creator {

  my $page = <<~"EOF";
  <!DOCTYPE html>
  <html>
  <head>
  <meta charset="utf-8">
  <style>
  body {
  
     background-color: black;
     color: #10EEEE;
  }
  h1 {
     text-align: center;
  }
  form {
     margin-top: 50px;
     margin-left: 100px;
  }
  input {
     margin: 5px;
     padding: 5px;

  }
  input[type=text] {
       width: 40%;
  }
  input[type=submit] {
       margin-top: 30px;
  }

  .subsection {
       margin-top: 30px;
       margin-bottom: 0px;
  }
  #help_button {
     margin-top: 100px;
     float: right;
  }
  #warn_msg {
  
     margin-top: 200px;
     margin-left: 100px;
  }
  #action_box {
  
     border: 1px dashed; 
     margin-top: 50px;
     margin-left: 100px;
     padding: 10px;
     width: 600px;
     height: 600px;
     display: none;
  }
  </style>
  </head>
  <body>
  <h1>Shadow Tune</h1>
  <div id="help_button"><button type="button" onclick="get_help()">Help</button></div>
  <div id="warn_msg"></div>
  <form id="shadow_form">
    <span>Path to Shadowrun game folder:</span><input type="text" name="sr_install"><br>
    <span>New resourcres.assets.resS file:</span><input type="text" name="new_resS"><br>
    <p class="subsection">Action:</p><br>
      <input type="radio" name="action" value="swap" checked>Replace<br>
      <input type="radio" name="action" value="restore">Restore<br>
    <p class="subsection">Shadowrun game:</p><br>
      <input type="radio" name="edition" value="Returns" checked>Shadowrun Returns<br>
      <input type="radio" name="edition" value="Dragonfall">Shadowrun Dragonfall<br>
      <input type="radio" name="edition" value="Hongkong">Shadowrun Hong Kong<br>
    <p class="subsection">Other options:</p><br>
      <input type="radio" name="verbose" value=1>Verbose output<br>  
    <input type="submit" value="Go">
  </form> 
  <div id="action_box"></div>
  <script>
     function toggle_box() { document.getElementById("action_box").style.display = "block"; }

     function get_help() {
          
          var xhreq = new XMLHttpRequest();
          xhreq.addEventListener("load", function(event) {
          
                   toggle_box();
                   document.getElementById("action_box").innerHTML = this.responseText;
               
          });
          xhreq.open("GET", "/help", true);
          xhreq.send();
     }

     function send_form () {

          var xhreq = new XMLHttpRequest();
          var form_content = new FormData(document.getElementById("shadow_form"));

          xhreq.addEventListener("load", function(event) {
               toggle_box();
               document.getElementById("action_box").innerHTML= this.responseText;
          });

          xhreq.addEventListener("error", function(event) {
               alert('Oops! Something went wrong.');
          });


          xhreq.open("POST", "/", true);
          xhreq.send(form_content);
     } 

     var form = document.getElementById("shadow_form");

     form.addEventListener("submit", function (event) {
          event.preventDefault();

          var resS_field = document.forms[0]["new_resS"].value;

          if (resS_field == "") {

               document.getElementById("warn_msg").innerHTML = "You must provide a new resources.assets.resS file!";
          } 
          else {

               send_form();
          }
     })
  </script>
  </body>
  </html>
  EOF

  return $page;  
  
}


sub content_display {

   my $cl_sock = shift;
   my $markup = shift;
   
   my $body_length = length(Encode::encode_utf8($markup)); 
   my $http_date =  POSIX::strftime("%a, %d %b %Y %R:%S GMT", gmtime);
   
   my $response = <<~"EOF";
   HTTP/1.1 200 OK\r  
   Date: $http_date\r
   Server: Eye of Terror\r
   Content-Type: text/html; charset=UTF-8\r
   Content-Length: $body_length\r
   Connection: close\r
   \r\n
   $markup 
   EOF
   
   select ($cl_sock);
   $| = 1;
   print $response;
   
   select (STDOUT);
   
}


sub get_option {
    
   shift @ARGV;
   die "Error, option without a value detected.\n" unless @ARGV != 0 && $ARGV[0] !~ /-+\w/; 

}


sub help_screen {
 
   $help_text = <<~"EOF"; 
   -Swap music files:
   $0 -swap <path-to-new-resources.assets.resS-file> [-e returns|dragonfall|hongkong ] [-i <path-to-shadowrun-install-folder>] [-v]
   The selected resources.assets.resS file should contain the new music tracks (in Ogg Vorbis format).
   The script will make a backup copy of the original resources.assets.resS that can later be used for the restore operation.
   -Restore original music:
   $0 -restore [-e returns|dragonfall|hongkong ] [-i <path-to-shadowrun-install-folder>] [-v]
   This operation will fail if the script can't locate the backup copy.
   EOF

   return $help_text;
}


my $port = 49003;

until (@ARGV == 0) {

  if ($ARGV[0] =~ /-*help/i) { print help_dialogue(); exit 0; }

  elsif ($ARGV[0] =~ /-p/) { get_option(); chomp($port = $ARGV[0]); }

  shift;

}

print "Listening on port: $port\n";

fork and exit;
print "Forked to background, pid = $$\n";

server_setup($port);

