#!/usr/bin/perl -w

#
#
# rwb.pl (Red, White, and Blue)
#
#
# Course Project code for EECS 339, Northwestern University
#
#
#

# The overall theory of operation of this script is as follows
#
# 1. The inputs are form parameters, if any, and a session cookie, if any. 
# 2. The session cookie contains the login credentials (User/Password).
# 3. The parameters depend on the form, but all forms have the following three
#    special parameters:
#
#         act      =  form  <the form in question> (form=base if it doesn't exist)
#         run      =  0 Or 1 <whether to run the form or not> (=0 if it doesn't exist)
#         debug    =  0 Or 1 <whether to provide debugging output or not> 
#
# 4. The script then generates relevant html based on act, run, and other 
#    parameters that are form-dependent
# 5. The script also sends back a new session cookie (allowing for logout functionality)
# 6. The script also sends back a debug cookie (allowing debug behavior to propagate
#    to child fetches)
#


#
# Debugging
#
# database input and output is paired into the two arrays noted
#
my $debug=0; # default - will be overriden by a form parameter or cookie
my @sqlinput=();
my @sqloutput=();

#
# The combination of -w and use strict enforces various 
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use strict;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);


# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.  
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle.
use DBI;

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;
use Digest::MD5 qw(md5 md5_hex md5_base64);


#
# You need to override these for access to your database
#
#my $dbuser="xdo579";
#my $dbpasswd="zVnnhy90L";
my $dbuser="pdinda";
my $dbpasswd="pdinda";

#
# The session cookie will contain the user's name and password so that 
# he doesn't have to type it again and again. 
#
# "RWBSession"=>"user/password"
#
# BOTH ARE UNENCRYPTED AND THE SCRIPT IS ALLOWED TO BE RUN OVER HTTP
# THIS IS FOR ILLUSTRATION PURPOSES.  IN REALITY YOU WOULD ENCRYPT THE COOKIE
# AND CONSIDER SUPPORTING ONLY HTTPS
#
my $cookiename="RWBSession";
#
# And another cookie to preserve the debug state
#
my $debugcookiename="RWBDebug";
my $locationcookiename="Location";
#
# Get the session input and debug cookies, if any
#
my $inputcookiecontent = cookie($cookiename);
my $inputdebugcookiecontent = cookie($debugcookiename);
my $inputlocationcookiecontent=cookie($locationcookiename);
#
# Will be filled in as we process the cookies and paramters
#
my $outputcookiecontent = undef;
my $outputdebugcookiecontent = undef;
my $deletecookie=0;
my $user = undef;
my $password = undef;
my $logincomplain=0;

#
# Get the user action and whether he just wants the form or wants us to
# run the form
#
my $action;
my $run;
my %label=('Republican'=>1,'Democratic'=>-1,'Neutral'=>0,);

if (defined(param("act"))) { 
  $action=param("act");
  if (defined(param("run"))) { 
    $run = param("run") == 1;
  } else {
    $run = 0;
  }
} else {
  $action="base";
  $run = 1;
}

my $dstr;

if (defined(param("debug"))) { 
  # parameter has priority over cookie
  if (param("debug") == 0) { 
    $debug = 0;
  } else {
    $debug = 1;
  }
} else {
  if (defined($inputdebugcookiecontent)) { 
    $debug = $inputdebugcookiecontent;
  } else {
    # debug default from script
  }
}

$outputdebugcookiecontent=$debug;

#
#
# Who is this?  Use the cookie or anonymous credentials
#
#
if (defined($inputcookiecontent)) { 
  # Has cookie, let's decode it
  ($user,$password) = split(/\//,$inputcookiecontent);
  $outputcookiecontent = $inputcookiecontent;
} else {
  # No cookie, treat as anonymous user
  ($user,$password) = ("anon","anonanon");
}

#####Give opinion

if($action eq "give-user-opinion"){

}
#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ($action eq "login") { 
  if ($run) { 
    #
    # Login attempt
    #
    # Ignore any input cookie.  Just validate user and
    # generate the right output cookie, if any.
    #
    my $x = 0;
    ($user,$password) = (param('user'),param('password'));
    
    my $newpassword;
    if($user eq "root"){
			$newpassword=$password;
    } else {
    	$newpassword = encode($password,$x);
    }
  if (ValidUser($user,$newpassword)) { 
      # if the user's info is OK, then give him a cookie
      # that contains his username and password 
      # the cookie will expire in one hour, forcing him to log in again
      # after one hour of inactivity.
      # Also, land him in the base query screen
      $outputcookiecontent=join("/",$user,$password);
      $action = "base";
      $run = 1;
    } else {
      # uh oh.  Bogus login attempt.  Make him try again.
      # don't give him a cookie
      $logincomplain=1;
      $action="login";
      $run = 0;
    }
  } else {
    #
    # Just a login screen request, but we should toss out any cookie
    # we were given
    #
    undef $inputcookiecontent;
    ($user,$password)=("anon","anonanon");
  }
} 


#
# If we are being asked to log out, then if 
# we have a cookie, we should delete it.
#
if ($action eq "logout") {
  $deletecookie=1;
  $action = "base";
  $user = "anon";
  $password = "anonanon";
  $run = 1;
}


my @outputcookies;

#
# OK, so now we have user/password
# and we *may* have an output cookie.   If we have a cookie, we'll send it right 
# back to the user.
#
# We force the expiration date on the generated page to be immediate so
# that the browsers won't cache it.
#
if (defined($outputcookiecontent)) { 
  my $cookie=cookie(-name=>$cookiename,
		    -value=>$outputcookiecontent,
		    -expires=>($deletecookie ? '-1h' : '+1h'));
  push @outputcookies, $cookie;
} 
#
# We also send back a debug cookie
#
#
if (defined($outputdebugcookiecontent)) { 
  my $cookie=cookie(-name=>$debugcookiename,
		    -value=>$outputdebugcookiecontent);
  push @outputcookies, $cookie;
}

#
# Headers and cookies sent back to client
#
# The page immediately expires so that it will be refetched if the
# client ever needs to update it
#
print header(-expires=>'now', -cookie=>\@outputcookies);

#
# Now we finally begin generating back HTML
#
#
#print start_html('Red, White, and Blue');
print "<html style=\"height: 100\%\">";
print "<head>";
print "<title>Red, White, and Blue</title>";
print "</head>";

print "<body style=\"height:100\%;margin:0\">";

#
# Force device width, for mobile phones, etc
#
#print "<meta name=\"viewport\" content=\"width=device-width\" />\n";

# This tells the web browser to render the page in the style
# defined in the css file
#
print "<style type=\"text/css\">\n\@import \"rwb.css\";\n</style>\n";
  

print "<center>" if !$debug;


#
#
# The remainder here is essentially a giant switch statement based
# on $action. 
#
#
#


# LOGIN
#
# Login is a special case since we handled running the filled out form up above
# in the cookie-handling code.  So, here we only show the form if needed
# 
#
if ($action eq "login") { 
  if ($logincomplain) { 
    print "Login failed.  Try again.<p>"
  } 
  if ($logincomplain or !$run) { 
    print start_form(-name=>'Login'),
      h2('Login to Red, White, and Blue'),
	"Name:",textfield(-name=>'user'),	p,
	  "Password:",password_field(-name=>'password'),p,
	    hidden(-name=>'act',default=>['login']),
	      hidden(-name=>'run',default=>['1']),
		submit,
		  end_form;
  }
}



#
# BASE
#
# The base action presents the overall page to the browser
#
#
#
if ($action eq "base") { 
  #
  # Google maps API, needed to draw the map
  #
  print "<script src=\"http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js\" type=\"text/javascript\"></script>";
  print "<script src=\"http://maps.google.com/maps/api/js?sensor=false\" type=\"text/javascript\"></script>";
  
  #
  # The Javascript portion of our app
  #
  print "<script type=\"text/javascript\" src=\"rwb.js\"> </script>";



  #
  #
  # And something to color (Red, White, or Blue)
  #
  print "<div id=\"color\" style=\"width:100\%; height:10\%\"></div>";

  #
  #
  # And a map which will be populated later
  #
  print "<div id=\"map\" style=\"width:100\%; height:80\%\"></div>";
  
  
  #
  # And a div to populate with info about nearby stuff
  #
  #
  if ($debug) {
    # visible if we are debugging
    print "<div id=\"data\" style=\:width:100\%; height:10\%\"></div>";
  } else {
    # invisible otherwise
    print "<div id=\"data\" style=\"display: none;\"></div>";
  }


# height=1024 width=1024 id=\"info\" name=\"info\" onload=\"UpdateMap()\"></iframe>";
  
  #
  # User mods
  #
  #
  if ($user eq "anon") {
    print "<p>You are anonymous, but you can also <a href=\"rwb.pl?act=login\">login</a></p>";
  } else {
    print "<p>You are logged in as $user and can do the following:</p>";
    if (UserCan($user,"give-opinion-data")) {
      print "<p><a href=\"rwb.pl?act=give-opinion-data\">Give Opinion Of Current Location</a></p>";
    }
    if (UserCan($user,"give-cs-ind-data")) {
      print "<p><a href=\"rwb.pl?act=give-cs-ind-data\">Geolocate Individual Contributors</a></p>";
    }
    if (UserCan($user,"manage-users") || UserCan($user,"invite-users")) {
      print "<p><a href=\"rwb.pl?act=invite-user\">Invite User</a></p>";
    }
    if (UserCan($user,"manage-users") || UserCan($user,"add-users")) { 
      print "<p><a href=\"rwb.pl?act=add-user\">Add User</a></p>";
    } 
    if (UserCan($user,"manage-users")) { 
      print "<p><a href=\"rwb.pl?act=delete-user\">Delete User</a></p>";
      print "<p><a href=\"rwb.pl?act=add-perm-user\">Add User Permission</a></p>";
      print "<p><a href=\"rwb.pl?act=revoke-perm-user\">Revoke User Permission</a></p>";
    }
    print "<p><a href=\"rwb.pl?act=logout&run=1\">Logout</a></p>";
    #checkbox for group selection------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
    print "<div id='checkboxes'>";
    print "<div>Which information you want to show:</div>";
    print "<form><input type=\"checkbox\" id=\"committeeid\" onchange='ViewShift()' checked=true>Committees</input><br><input type=\"checkbox\" onchange='ViewShift()' id=\"candidateid\" >Candidates</input><br><input type=\"checkbox\" id=\"individualid\" onchange='ViewShift()'>Individuals</input><br><input type=\"checkbox\" onchange='ViewShift()'  id=\"opinionid\" >Opinions</input></form>";
    print "</div>";
    print "<div>";
    print "<p>You can choose following cycles:</p>";
   #checkbox for cyclce selection
    my @cycle_sel;
    eval { 
      @cycle_sel = ExecSQL($dbuser, $dbpasswd,"select distinct cycle from cs339.candidate_master order by cycle");
    };
    #find out all cycle of election from tables
    print "<div id ='Cycle choice'>";
    my $i;
    for ($i = 0;$i <= $#cycle_sel;$i++){
      print "<input type='checkbox' value='$cycle_sel[$i][0]' class='cycletocheck' onchange='ViewShift()'>$cycle_sel[$i][0]<br>";
    }
    print "</div>";
    print "</div>";
    print "<p></p>";
    print "<div id=\"s1\"></div>";
    print "<p></p>";
    print "<div id=\"s2\"></div>";
    print "<p></p>";
    print "<div id=\"s3\"></div>";
  }

}

#
#
# NEAR
#
#
# Nearby committees, candidates, individuals, and opinions
#
#
# Note that the individual data should integrate the FEC data and the more
# precise crowd-sourced location data.   The opinion data is completely crowd-sourced
#
# This form intentionally avoids decoration since the expectation is that
# the client-side javascript will invoke it to get raw data for overlaying on the map
#
#
if ($action eq "near") {
  my $latne = param("latne");
  my $longne = param("longne");
  my $latsw = param("latsw");
  my $longsw = param("longsw");
  my $whatparam = param("what");
  my $format = param("format");
  my $cycle = param("cycle");
  my %what;
  
  $format = "table" if !defined($format);
  $cycle = "1112" if !defined($cycle);

  if (!defined($whatparam) || $whatparam eq "all") { 
    %what = ( committees => 1, 
	      candidates => 1,
	      individuals =>1,
	      opinions => 1);
  } else {
    map {$what{$_}=1} split(/\s*,\s*/,$whatparam);
  }
	     
  if ($what{committees}) { 
    my ($str,$error) = Committees($latne,$longne,$latsw,$longsw,$cycle,$format);
    my ($dem,$error1) = CommitteeDEMsum($latne,$longne,$latsw,$longsw,$cycle);
    my ($rep,$error2) = CommitteeREPsum($latne,$longne,$latsw,$longsw,$cycle);
    if (!$error1 && !$error2) {
      my $sum = $dem + $rep;

      while($sum == 0) {
        $latne += .1;
        $longne += .1;    
  			$latsw -= .1;
        $longsw -= .1;

        ($dem,$error1) = CommitteeDEMsum($latne,$longne,$latsw,$longsw,$cycle);
				($rep,$error2) = CommitteeREPsum($latne,$longne,$latsw,$longsw,$cycle);
        $sum = $dem + $rep;
      }
      my $diff = $dem - $rep;
      
      if ($diff > 0) {
				print "<div id=\"stat1\" bgColor=\"#00ffff\">";
				print "<p>This is the fund sumary of committees</p>";
				print "<table style='background-color:blue' borderColor=\"#00ff99\"><tbody><tr><td>DEM fund</td><td>$dem</td></tr><tr><td>REP fund</td><td>$rep</td></tr><tr><td>Total fund</td><td>$sum</td></tr></tbody></table>";
				print "</div>";
      } 
      if ($diff < 0) {
				print "<div id=\"stat1\" bgColor=\"#00ffff\">";
				print "<p>This is the fund sumary of committees</p>";
				print "<table style='background-color:red' borderColor=\"#00ff99\"><tbody><tr><td>DEM fund</td><td>$dem</td></tr><tr><td>REP fund</td><td>$rep</td></tr><tr><td>Total fund</td><td>$sum</td></tr></tbody></table>";
				print "</div>";
      } 
      if ($diff == 0) {
				print "<div id=\"stat1\" bgColor=\"#00ffff\">";
				print "<p>This is the fund sumary of committees</p>";
				print "<table style='background-color:white' borderColor=\"#00ff99\"><tbody><tr><td>DEM fund</td><td>$dem</td></tr><tr><td>REP fund</td><td>$rep</td></tr><tr><td>Total fund</td><td>$sum</td></tr></tbody></table>";
				print "</div>";
      }
    }

    if (!$error) {
      if ($format eq "table") { 
				print "<h2>Nearby committees</h2>$str";
      } else {
				print $str;
      }
    }
  }

  if ($what{candidates}) {
    my ($str,$error) = Candidates($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
				print "<h2>Nearby candidates</h2>$str";
      } else {
				print $str;
      }
    }
  }
  if ($what{individuals}) {
    my ($str,$error) = Individuals($latne,$longne,$latsw,$longsw,$cycle,$format);
    my ($dem,$error1) = IndividualDEMsum($latne,$longne,$latsw,$longsw,$cycle);
    my ($rep,$error2) = IndividualREPsum($latne,$longne,$latsw,$longsw,$cycle);
    if (!$error1 && !$error2) {
      my $sum = $dem + $rep;
      while($sum == 0) {
        $latne += .1;
        $longne += .1;    
  			$latsw -= .1;
        $longsw -= .1;

        ($dem,$error1) = IndividualDEMsum($latne,$longne,$latsw,$longsw,$cycle);
				($rep,$error2) = IndividualREPsum($latne,$longne,$latsw,$longsw,$cycle);
        $sum = $dem + $rep;
			}

      my $diff = $dem - $rep;
      
      if ($diff > 0) {
				print "<div id=\"stat2\" bgColor=\"#00ffff\">";
				print "<p>This is the fund sumary of individuals</p>";
				print "<table style='background-color:blue' borderColor=\"#00ff99\"><tbody><tr><td>DEM fund</td><td>$dem</td></tr><tr><td>REP fund</td><td>$rep</td></tr><tr><td>Total fund</td><td>$sum</td></tr></tbody></table>";
				print "</div>";
      } 
      if ($diff < 0) {
				print "<div id=\"stat2\" bgColor=\"#00ffff\">";
				print "<p>This is the fund sumary of individuals</p>";
				print "<table style='background-color:red' borderColor=\"#00ff99\"><tbody><tr><td>DEM fund</td><td>$dem</td></tr><tr><td>REP fund</td><td>$rep</td></tr><tr><td>Total fund</td><td>$sum</td></tr></tbody></table>";
				print "</div>";
      } 
      if ($diff == 0) {
				print "<div id=\"stat2\" bgColor=\"#00ffff\">";
				print "<p>This is the fund sumary of individuals</p>";
				print "<table style='background-color:white' borderColor=\"#00ff99\"><tbody><tr><td>DEM fund</td><td>$dem</td></tr><tr><td>REP fund</td><td>$rep</td></tr><tr><td>Total fund</td><td>$sum</td></tr></tbody></table>";
				print "</div>";
      }
     }

     if (!$error) {
     	if ($format eq "table") { 
	 			print "<h2>Nearby individuals</h2>$str";
     	} else {
	 			print $str;
     	}
		}
  }
  if ($what{opinions}) {
    my ($str,$error) = Opinions($latne,$longne,$latsw,$longsw,$cycle,$format);
   	my(@sum,$error1) = opinionsum($latne,$longne,$latsw,$longsw);
    my $sum;
    if (!$error1) {
      while($sum[0]==0 && $sum[1]==0) {
				$latne += .1;
        $longne += .1;
        $latsw -= .1;
        $longsw -= .1;
				(@sum,$error1)= opinionsum($latne,$longne,$latsw,$longsw);
      }
    }

      if ($sum[0] > 0) {
				print "<div id=\"stat3\" bgColor=\"#00ffff\">";
			 	print "<p>This is the fund sumary of individuals</p>";
				print "<table style='background-color:blue' borderColor=\"#00ff99\"><tbody><tr><td>Average</td><td>$sum[0]</td></tr><tr><td>Standard Deviation</td><td>$sum[1]</td></tr></tbody></table>";
				print "</div>";
      } 
		  if ($sum[0] < 0) {
				print "<div id=\"stat3\" bgColor=\"#00ffff\">";
				print "<p>This is the fund sumary of individuals</p>";
				print "<table style='background-color:red' borderColor=\"#00ff99\"><tbody><tr><td>Average</td><td>$sum[0]</td></tr><tr><td>Standard Deviation</td><td>$sum[1]</td></tr></tbody></table>";
				print "</div>";
		  } 
    if ($sum[0] == 0) {
			print "<div id=\"stat3\" bgColor=\"#00ffff\">";
  		print "<p>This is the fund sumary of individuals</p>";
			print "<table style='background-color:white' borderColor=\"#00ff99\"><tbody><tr><td>Average</td><td>$sum[0]</td></tr><tr><td>Standard Deviation</td><td>$sum[1]</td></tr></tbody></table>";
			print "</div>";
    } 

    if (!$error) {
      if ($format eq "table") { 
				print "<h2>Nearby opinions</h2>$str";
      } else {
				print $str;
      }
    }
  }
}
if($action eq "register"){
	my $uuid=param("uuid");
	my @used=eval{ExecSQL($dbuser,$dbpasswd,"select used from rwb_uuid where id=?",undef,$uuid);};
	my $num_ref=@used[0];
	my $used_num=@{$num_ref}[0];
	if($used_num==1){
		print h2('This link has been used before');
	}else{
		if(!$run){
			print start_form(-name=>'register'),
			h2('Register'),
				"Name:",textfield(-name=>'name'),
				p,
				"Email:",textfield(-name=>'email'),
				p,
				"Password:",textfield(-name=>'password'),
				p,
			hidden(-name=>'run',-default=>['1']),
			hidden(-name=>'refer',-default=>[param('refer')]),
			hidden(-name=>'act',-default=>['register']),
			hidden(-name=>'uuid',-default=>[$uuid]),
			submit,
			end_form,
			hr;
			print "Kindly Reminder:**password must be 8 characters";
		}else{
			my $x=0;
			my $name=param('name');
			my $password=param('password');
			my $email=param('email');
			my $refer=param('refer');
			my $error;
			my $newpw=encode($password,$x);
			$error=UserAdd($name,$newpw,$email,$refer);
			if($error){
				print "could not register because of the $error";
			} else {
				my $error_invite;
				$error_invite=GiveUserPerm($name,'invite-users');
				my $error_add;
				$error_add=GiveUserPerm($name,'add-users');
				my $error_opinion;
				$error_opinion=GiveUserPerm($name,'give-opinion-data');
				my $error_fec;
				$error_fec=GiveUserPerm($name,'query-fec-data');
				my $error_cs1;
				$error_cs1=GiveUserPerm($name,'query-cs-ind-data');
				my $error_cs2;
				$error_cs2=GiveUserPerm($name,'give-cs-ind-data');
				my $error_qopinion;
				$error_qopinion=GiveUserPerm($name,'query-opinion-data');

				if($error_invite){
					print "Cannot give user permission because of $error_invite";
				}elsif($error_add){
					print "Cannot give user permission because of $error_add";
				}elsif($error_opinion){
					print "Cannot give user permission because of $error_opinion";}
				elsif($error_fec){
					print "Cannot give user permission because of $error_fec";}
				elsif($error_cs1){
					print "Cannot give user permission because of $error_cs1";}
				elsif($error_cs2){
					print "Cannot give user permission because of $error_cs2";}
				elsif($error_qopinion){
					print "Cannot give user permission because of $error_qopinion";}
				else{
					print "Your registration is complete!\n";
				}
				eval {ExecSQL($dbuser,$dbpasswd,"update rwb_uuid set used=1 where id=?",undef,$uuid);}
			}
		}
	}
	print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";}
	if ($action eq "invite-user") { 
		if(!UserCan($user,"add-users")&& !UserCan($user,"manage-users")&& !UserCan($user,"invite-users")) { 
			print h2("Cannot invite user!");
		}else{
			if(!$run){
				print start_form(-name=>'InviteUser'),
				h2('Invite User'),
				"Email: ",textfield(-name=>'email'),
				p,
				hidden(-name=>'run',-default=>['1']),
				hidden(-name=>'act',-default=>['invite-user']),
				submit,
				hr,
				end_form;
			}else{  
				my $email=param('email');
				my $error;
				$error=UserInvite($email);
				if($error){
				print "Cannot invite user because:$error";
			}else{   
				print "The invite email is $email as referred by $user\n";
			}
		}
	}
	print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}


if ($action eq "give-cs-ind-data") { 
  print h2("Giving Crowd-sourced Individual Geolocations Is Unimplemented");
}

# ADD-USER
#
# User Add functionaltiy 

if ($action eq "add-user") { 
  if (!UserCan($user,"add-users") && !UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to add users.');
  } else {
    if (!$run) { 
      print start_form(-name=>'AddUser'),
			h2('Add User'),
	  	"Name: ", textfield(-name=>'name'),
	    p,
	    "Email: ", textfield(-name=>'email'),
			p,
		  "Password: ", textfield(-name=>'password'),
		  p,
		  hidden(-name=>'run',-default=>['1']),
			hidden(-name=>'act',-default=>['add-user']),
			  submit,
			    end_form,
			      hr;
    } else {
      my $name=param('name');
      my $email=param('email');
      my $password=param('password');
      my $error;
      $error=UserAdd($name,$password,$email,$user);
      if ($error) { 
				print "Can't add user because: $error";
      } else {
				print "Added user $name $email as referred by $user\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}

#
# DELETE-USER
#
# User Delete functionaltiy 
#
#
#
#
if ($action eq "delete-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to delete users.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'DeleteUser'),
			h2('Delete User'),
	  	"Name: ", textfield(-name=>'name'),
	    p,
	    hidden(-name=>'run',-default=>['1']),
			hidden(-name=>'act',-default=>['delete-user']),
		  submit,
		  end_form,
		  hr;
    } else {
      my $name=param('name');
      my $error;
      $error=UserDel($name);
      if ($error) { 
				print "Can't delete user because: $error";
      } else {
				print "Deleted user $name\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}
#GIVE-OPINION-DATA

if($action eq "give-opinion-data"){
	my $run = param('run');
	my $party=param('party_affiliation');
	#my %label=('Republican'=>1,'Democratic'=>-1,'Neutral'=>0,);
	my ($lat,$log)=(undef,undef);
	if(defined($inputlocationcookiecontent)){
		($lat,$log)=split(/\//,$inputlocationcookiecontent);
	}
	if(!UserCan($user,"give-opinion-data")){
		print h2('Sorry, you do not have permission to give opinion.');
	}else{
		if(!$run){
			print h2("Make your selection");
			print start_form(-name=>'GiveOpinion'),
			radio_group(-name=>'party_affiliation',-values=>['Republican','Democratic','Neutral']),
			hidden(-name=>'run',-default=>['1']),
			hidden(-name=>'lat',-default=>[param('lat')]),
			hidden(-name=>'log',-default=>[param('log')]),
			hidden(-name=>'act',-default=>['give-opinion-data']);
			print submit,end_form;
			print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
		}else{
			if(defined($lat)&&defined($log)){
			eval{
				ExecSQL($dbuser,$dbpasswd,"insert into rwb_opinions(submitter,color,latitude,longitude) values (?,?,?,?)",undef,$user,$label{$party},$lat,$log);};
				print "Your opinion has been recorded in the place of ($lat,$log).";
			}else{
				print h2("Cannot get your location");
			}
			print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
		}
	}
}




# ADD-PERM-USER
# User Add Permission functionaltiy 


if ($action eq "add-perm-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage user permissions.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'AddUserPerm'),
			h2('Add User Permission'),
	  	"Name: ", textfield(-name=>'name'),
	    "Permission: ", textfield(-name=>'permission'),
	    p,
			hidden(-name=>'run',-default=>['1']),
		  hidden(-name=>'act',-default=>['add-perm-user']),
			submit,
			end_form,
			hr;
      my ($table,$error);
      ($table,$error)=PermTable();
      if (!$error) { 
				print "<h2>Available Permissions</h2>$table";
      }
    } else {
      my $name=param('name');
      my $perm=param('permission');
      my $error=GiveUserPerm($name,$perm);
      if ($error) { 
				print "Can't add permission to user because: $error";
      } else {
				print "Gave user $name permission $perm\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}


#
# REVOKE-PERM-USER
#
# User Permission Revocation functionaltiy 
#
#
#
#
if ($action eq "revoke-perm-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage user permissions.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'RevokeUserPerm'),
			h2('Revoke User Permission'),
	  	"Name: ", textfield(-name=>'name'),
	    "Permission: ", textfield(-name=>'permission'),
	    p,
			hidden(-name=>'run',-default=>['1']),
		  hidden(-name=>'act',-default=>['revoke-perm-user']),
		  submit,
		  end_form,
		  hr;
      my ($table,$error);
      ($table,$error)=PermTable();
      if (!$error) { 
				print "<h2>Available Permissions</h2>$table";
      }
    } else {
      my $name=param('name');
      my $perm=param('permission');
      my $error=RevokeUserPerm($name,$perm);
      if ($error) { 
				print "Can't revoke permission from user because: $error";
      } else {
				print "Revoked user $name permission $perm\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}



#
#
#
#
# Debugging output is the last thing we show, if it is set
#
#
#
#

print "</center>" if !$debug;

#
# Generate debugging output if anything is enabled.
#
#
if ($debug) {
  print hr, p, hr,p, h2('Debugging Output');
  print h3('Parameters');
  print "<menu>";
  print map { "<li>$_ => ".escapeHTML(param($_)) } param();
  print "</menu>";
  print h3('Cookies');
  print "<menu>";
  print map { "<li>$_ => ".escapeHTML(cookie($_))} cookie();
  print "</menu>";
  my $max= $#sqlinput>$#sqloutput ? $#sqlinput : $#sqloutput;
  print h3('SQL');
  print "<menu>";
  for (my $i=0;$i<=$max;$i++) { 
    print "<li><b>Input:</b> ".escapeHTML($sqlinput[$i]);
    print "<li><b>Output:</b> $sqloutput[$i]";
  }
  print "</menu>";
}

print end_html;

#
# The main line is finished at this point. 
# The remainder includes utilty and other functions
#


#
# Generate a table of nearby committees
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Committees {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, cmte_nm, cmte_pty_affiliation, cmte_st1, cmte_st2, cmte_city, cmte_st, cmte_zip from cs339.committee_master natural join cs339.cmte_id_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("committee_data","2D",
			["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
			@rows),$@);
    } else {
      return (MakeRaw("committee_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of nearby candidates
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Candidates {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, cand_name, cand_pty_affiliation, cand_st1, cand_st2, cand_city, cand_st, cand_zip from cs339.candidate_master natural join cs339.cand_id_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") {
      return (MakeTable("candidate_data", "2D",
			["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
			@rows),$@);
    } else {
      return (MakeRaw("candidate_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of nearby individuals
#
# Note that the handout version does not integrate the crowd-sourced data
#
# ($table|$raw,$error) = Individuals(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Individuals {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, name, city, state, zip_code, employer, transaction_amnt from cs339.individual natural join cs339.ind_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("individual_data", "2D",
			["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
			@rows),$@);
    } else {
      return (MakeRaw("individual_data","2D",@rows),$@);
    }
  }
}

# Generate a table of nearby opinions
#
# ($table|$raw,$error) = Opinions(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Opinions {
  my ($latne, $longne, $latsw, $longsw, $cycle,$format) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, color from rwb_opinions where latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("opinion_data","2D",
			["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
			@rows),$@);
    } else {
      return (MakeRaw("opinion_data","2D",@rows),$@);
    }
  }
}

sub UserInvite {
	my ($email) = @_;
	my $uuid = time();
	my $used = 0;
	my $link = "http://murphy.wot.eecs.northwestern.edu/~xdo579/rwb/rwb.pl?act=register&refer=$user&uuid=$uuid";
	eval { 
		ExecSQL($dbuser,$dbpasswd, "insert into rwb_uuid (id, used) values (?,?)",undef,$uuid, $used);
	};
	my $subject = "Your new Account";
	my $content = "Click here to setup your account. \n $link";
	open(MAIL,"| mail -s $subject $email") or die "Can't run mail\n";
	print MAIL $content;
	close(MAIL);	
}

sub InviteCancel{
	my $code=$_[0];
	eval{
		ExecSQL($dbuser,$dbpasswd,"cancel invitation from rwb_invite where code=?",undef,$code);
	};
	return $@;
}
#
# Generate a table of available permissions
# ($table,$error) = PermTable()
# $error false on success, error string on failure
#
sub PermTable {
  my @rows;
  eval { 
  	@rows = ExecSQL($dbuser, $dbpasswd, "select action from rwb_actions"); 
  }; 
	if ($@) { 
		 return (undef,$@);
	} else {
		 return (MakeTable("perm_table",
				    "2D",
				   ["Perm"],
				   @rows),$@);
  }
}

#
# Generate a table of users
# ($table,$error) = UserTable()
# $error false on success, error string on failure
#
sub UserTable {
  my @rows;
  eval { 
  	@rows = ExecSQL($dbuser, $dbpasswd, "select name, email from rwb_users order by name"); 
  }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("user_table",
		      "2D",
		     ["Name", "Email"],
		     @rows),$@);
  }
}

#
# Generate a table of users and their permissions
# ($table,$error) = UserPermTable()
# $error false on success, error string on failure
#
sub UserPermTable {
  my @rows;
  eval { 
  	@rows = ExecSQL($dbuser, $dbpasswd, "select rwb_users.name, rwb_permissions.action from rwb_users, rwb_permissions where rwb_users.name=rwb_permissions.name order by rwb_users.name"); 
  }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("userperm_table",
		      "2D",
		     ["Name", "Permission"],
		     @rows),$@);
  }
}

#
# Add a user
# call with name,password,email
#
# returns false on success, error string on failure.
# 
# UserAdd($name,$password,$email)
#
sub UserAdd { 
  eval { 
  	ExecSQL($dbuser,$dbpasswd, "insert into rwb_users (name,password,email,referer) values (?,?,?,?)",undef,@_);
  };
  return $@;
}

#
# Delete a user
# returns false on success, $error string on failure
# 
sub UserDel { 
  eval {
  	ExecSQL($dbuser,$dbpasswd,"delete from rwb_users where name=?", undef, @_);
  };
  return $@;
}


#
# Give a user a permission
#
# returns false on success, error string on failure.
# 
# GiveUserPerm($name,$perm)
#
sub GiveUserPerm { 
  eval { 
  	ExecSQL($dbuser,$dbpasswd, "insert into rwb_permissions (name,action) values (?,?)",undef,@_);
  };
  return $@;
}

#
# Revoke a user's permission
#
# returns false on success, error string on failure.
# 
# RevokeUserPerm($name,$perm)
#
sub RevokeUserPerm { 
  eval { 
  	ExecSQL($dbuser,$dbpasswd, "delete from rwb_permissions where name=? and action=?",undef,@_);
  };
  return $@;
}

#
#
# Check to see if user and password combination exist
#
# $ok = ValidUser($user,$password)
#
#
sub ValidUser {
  my ($user,$password)=@_;
  my @col;
  eval {
  	@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_users where name=? and password=?","COL",$user,$password);
  };
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}


#
#
# Check to see if user can do some action
#
# $ok = UserCan($user,$action)
#
sub UserCan {
  my ($user,$action)=@_;
  my @col;
  eval {
  	@col= ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_permissions where name=? and action=?","COL",$user,$action);
  };
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}





#
# Given a list of scalars, or a list of references to lists, generates
# an html table
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
# $headerlistref points to a list of header columns
#
#
# $html = MakeTable($id, $type, $headerlistref,@list);
#
sub MakeTable {
  my ($id,$type,$headerlistref,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  if ((defined $headerlistref) || ($#list>=0)) {
    # if there is, begin a table
    #
    $out="<table id=\"$id\" border>";
    #
    # if there is a header list, then output it in bold
    #
    if (defined $headerlistref) { 
      $out.="<tr>".join("",(map {"<td><b>$_</b></td>"} @{$headerlistref}))."</tr>";
    }
    #
    # If it's a single row, just output it in an obvious way
    #
    if ($type eq "ROW") { 
      #
      # map {code} @list means "apply this code to every member of the list
      # and return the modified list.  $_ is the current list member
      #
      $out.="<tr>".(map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>" } @list)."</tr>";
    } elsif ($type eq "COL") { 
      #
      # ditto for a single column
      #
      $out.=join("",map {defined($_) ? "<tr><td>$_</td></tr>" : "<tr><td>(null)</td></tr>"} @list);
    } else { 
      #
      # For a 2D table, it's a bit more complicated...
      #
      $out.= join("",map {"<tr>$_</tr>"} (map {join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @{$_})} @list));
    }
    $out.="</table>";
  } else {
    # if no header row or list, then just say none.
    $out.="(none)";
  }
  return $out;
}


#
# Given a list of scalars, or a list of references to lists, generates
# an HTML <pre> section, one line per row, columns are tab-deliminted
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
#
# $html = MakeRaw($id, $type, @list);
#
sub MakeRaw {
  my ($id, $type,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  $out="<pre id=\"$id\">\n";
  #
  # If it's a single row, just output it in an obvious way
  #
  if ($type eq "ROW") { 
    #
    # map {code} @list means "apply this code to every member of the list
    # and return the modified list.  $_ is the current list member
    #
    $out.=join("\t",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } elsif ($type eq "COL") { 
    #
    # ditto for a single column
    #
    $out.=join("\n",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } else {
    #
    # For a 2D table
    #
    foreach my $r (@list) { 
      $out.= join("\t", map { defined($_) ? $_ : "(null)" } @{$r});
      $out.="\n";
    }
  }
  $out.="</pre>\n";
  return $out;
}

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
sub ExecSQL {
  my ($user, $passwd, $querystring, $type, @fill) =@_;
  if ($debug) { 
    # if we are recording inputs, just push the query string and fill list onto the 
    # global sqlinput list
    push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
  }
  my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
  if (not $dbh) { 
    # if the connect failed, record the reason to the sqloutput list (if set)
    # and then die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
    }
    die "Can't connect to database because of ".$DBI::errstr;
  }
  my $sth = $dbh->prepare($querystring);
  if (not $sth) { 
    #
    # If prepare failed, then record reason to sqloutput and then die
    #
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  if (not $sth->execute(@fill)) { 
    #
    # if exec failed, record to sqlout and die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  #
  # The rest assumes that the data will be forthcoming.
  #
  #
  my @data;
  if (defined $type and $type eq "ROW") { 
    @data=$sth->fetchrow_array();
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","ROW",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  my @ret;
  while (@data=$sth->fetchrow_array()) {
    push @ret, [@data];
  }
  if (defined $type and $type eq "COL") { 
    @data = map {$_->[0]} @ret;
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","COL",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  $sth->finish();
  if ($debug) {push @sqloutput, MakeTable("debug_sql_output","2D",undef,@ret);}
  $dbh->disconnect();
  return @ret;
}

sub CommitteeDEMsum {
    my ($latne,$longne,$latsw,$longsw,$cycle) = @_;
    my @sum;
    my $sum;
    eval{ @sum = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt) from ((select transaction_amnt, cmte_id from cs339.comm_to_comm natural join cs339.cmte_id_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<?) union all (select transaction_amnt, cmte_id from cs339.comm_to_cand natural join cs339.cmte_id_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<?)) where cmte_id in (select cmte_id from cs339.committee_master where cmte_pty_affiliation='DEM')","COL",$latsw,$latne,$longsw,$longne,$latsw,$latne,$longsw,$longne);};            
    return($sum[0],$@);
}

sub CommitteeREPsum {
    my ($latne,$longne,$latsw,$longsw,$cycle) = @_;
    my @sum;
    my $sum;
    eval{ @sum = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt) from ((select transaction_amnt, cmte_id from cs339.comm_to_comm natural join cs339.cmte_id_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<?) union all (select transaction_amnt, CMTE_ID from cs339.comm_to_cand natural join cs339.cmte_id_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<?)) where cmte_id in (select cmte_id from cs339.committee_master where cmte_pty_affiliation='REP')","COL",$latsw,$latne,$longsw,$longne,$latsw,$latne,$longsw,$longne);};  
    return($sum[0],$@);
}

sub IndividualDEMsum {
    my($latne,$longne,$latsw,$longsw,$cycle) = @_;
    my $sum;
    my @sum;
    eval { @sum = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt) from cs339.individual natural join cs339.ind_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<? and cs339.individual.cmte_id in (select cmte_id from cs339.committee_master where cmte_pty_affiliation ='DEM')","COL",$latsw,$latne,$longsw,$longne);};
    return($sum[0],$@);
}

sub IndividualREPsum {
    my($latne,$longne,$latsw,$longsw,$cycle) = @_;
    my $sum;
    my @sum;
    eval { @sum = ExecSQL($dbuser,$dbpasswd,"select sum(transaction_amnt) from cs339.individual natural join cs339.ind_to_geo where cycle in (".$cycle.") and latitude>? and latitude<? and longitude>? and longitude<? and cs339.individual.cmte_id in (select cmte_id from cs339.committee_master where cmte_pty_affiliation ='REP')","COL",$latsw,$latne,$longsw,$longne);};
    return($sum[0],$@);
}

sub opinionsum {
    my($latne,$longne,$latsw,$longsw)=@_;
    my @avg;
    eval { @avg = ExecSQL($dbuser,$dbpasswd,"select avg(color),stddev(color) from rwb_opinions where latitude>? and latitude<? and longitude>? and longitude<?","ROW",$latsw,$latne,$longsw,$longne);};
    return(@avg,$@);
}

sub encode {
  my ($x,$y) = @_;
  return md5($x);
}

=pod
sub encode {
  my ($x,$y) = @_;
    return "xy".$x."abc";
}
=cut
######################################################################
#
# Nothing important after this
#
######################################################################

# The following is necessary so that DBD::Oracle can
# find its butt
#
BEGIN {
  unless ($ENV{BEGIN_BLOCK}) {
    use Cwd;
    $ENV{ORACLE_BASE}="/raid/oracle11g/app/oracle/product/11.2.0.1.0";
    $ENV{ORACLE_HOME}=$ENV{ORACLE_BASE}."/db_1";
    $ENV{ORACLE_SID}="CS339";
    $ENV{LD_LIBRARY_PATH}=$ENV{ORACLE_HOME}."/lib";
    $ENV{BEGIN_BLOCK} = 1;
    exec 'env',cwd().'/'.$0,@ARGV;
  }
}

