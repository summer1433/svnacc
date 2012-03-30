#!/usr/bin/perl -w
use CGI;
use Fcntl qw(:flock SEEK_END);
my $q = CGI->new;

my $filename = "/Users/summer/Development/alipaywork/ecmng-svn/conf/newauthz";
my $passconf = "/Users/summer/Development/tools/httpd/dist/cgi-bin/pass.conf";
my $repoBase = "/home/admin/svntest";

$params = $q->Vars;

print $q->header;

$my_cmd = $params->{'cmd'};
if( "createRepo" eq $my_cmd ) {
		$reponame  = $params->{'reponame'};
		$repoAbsolute = $repoBase."/".$reponame;
		if($reponame && chomp($reponame) ne "") {
			if(-e $repoBase) {
				@args = ("svnadmin", "create", $repoAbsolute);
				if (system(@args) == 0 ) {
        	  print "success";
      	}  else {
        	  print "fail:", @args;
      	}
    	}else {
    		print "fail:".$repoBase."dir not exist";
    	}
		} else {
      print "fail:bad args";
    }
	
}
#manage account with password
if ( "uacc" eq $my_cmd ) {
        $account  = $params->{'account'};
        $passwd = $params->{'passwd'};

        if (   $account
                && $passwd
                && chomp($account)  ne ""
                && chomp($passwd) ne "" )
        {
                if ( -e $passconf ) {
                        @args = ( "htpasswd", "-db", $passconf, $account, $passwd );

                }
                else {

                        #create new pass.conf for accounts
                        @args = ( "htpasswd", "-dbc", $passconf, $account, $passwd );

                }

                if ( system(@args) == 0 ) {
                        print "execute htpasswd success!";
                }
                else {
                        print "fail to execute...", @args;
                }

        }
        else {
                print "bad args";
        }

}

#show access file by lines
if ( "showacc" eq $my_cmd ) {

        open( FH_AUTHZ, $filename );
        @lines = <FH_AUTHZ>;
        close(FH_AUTHZ);
        foreach (@lines) {
                chomp;
                print "$_\n";
        }

}

#edit access
if ( "editacc" eq $my_cmd ) {

### Author:summer.xt@alipay.com,2011/01/17
### Only support users!!! not support alias and goups
### Read file into Hashes to Hashes
### For Example:
### {
###         [repository:/dir/a/b] => {
###             summer.xt => "rw",
###         test.user => "r",
###         *         => "",
###      },
###
###      [/dir/c]             => {
###                     summer.xt => "r",
###         *         => "r",
###      },
### }

### It is simple to use :)
        $selected_repository_dir = $params->{'srd'};
        $selected_user           = $params->{'su'};
        $now_permit              = $params->{'np'};
        if (   $selected_repository_dir
                && $selected_user
                && chomp($selected_repository_dir) ne ""
                && chomp($selected_user) ne "" )
        {
                my $user_access_pattern = "";

                %access_hash = '';

                open( FH_AUTHZ, $filename );

                @lines = <FH_AUTHZ>;
                close(FH_AUTHZ);

                my $repostory_dir = "";

                #read file to hashes
                foreach (@lines) {

                        chomp;    #avoid \n on last field
                        if (/^\[(\w+[:]){0,1}([\/]([+-.]*\w)*)+\]$/) {
                                $repostory_dir = $_;
                                $access_hash{$repostory_dir}{''} = '';    #init a null hash
                        }

                        #       if(/^(\w+){0,1}$/) {
                        #               $repostory_dir = $_;
                        #       }
                        else {

                                if (/^((\**\w*)+([+-.]\w+)*[ ]*)=( *[rw]*)$/) {

                                        ( $key, $value ) = split /=/, $_;
                                        $access_hash{$repostory_dir}{$key} = $value;
                                }
                        }
                }

                #add something or modify hashes

                editPermit( $selected_repository_dir, $selected_user, $now_permit );

                #print to console
                hashstdout();

                #print hashes to file
                if ( writetofile($filename) eq 'true' ) {
                        print "result:success";
                }
        }
}

sub hashstdout {
        print "content:\n";
        for $dir ( sort keys %access_hash ) {    #sort before use it
                print "$dir\n";

                for $user_access ( sort keys %{ $access_hash{$dir} } )
                {                                    #sort before use it
                        if ( $user_access ne '' ) {
                                print "$user_access=$access_hash{$dir}{$user_access}\n";
                        }
                }

                print "\n";
        }
}

sub writetofile {
        my ($fn) = @_;
        open( my $fh_auhtz, "+>$fn" )
          or die "can't open file $fn";
        lock($fh_auhtz);

        for $dir ( sort keys %access_hash ) {    #sort before use it
                print $fh_auhtz "$dir\n";
                for $user_access ( sort keys %{ $access_hash{$dir} } )
                {                                    #sort before use it
                        if ( $user_access ne '' ) {
                                print $fh_auhtz
                                  "$user_access=$access_hash{$dir}{$user_access}\n";
                        }
                }
                print $fh_auhtz "\n";
        }
        unlock($fh_auhtz);

        close($fh_auhtz);
        return 'true';
}

sub lock {
        my ($fh) = @_;
        flock( $fh, LOCK_EX ) or die "Cannot lock file - $!\n";

        seek( $fh, 0, SEEK_END ) or die "Cannot seek - $!\n";
}

sub unlock {
        my ($fh) = @_;
        flock( $fh, LOCK_UN ) or die "Cannot unlock file - $!\n";

}

sub editPermit {
        my $dir    = $_[0];
        my $user   = $_[1];
        my $permit = $_[2];

        my %user_permit_hash;

        if ( $dir eq "[]" ) {
                for $d ( sort keys %access_hash ) {    #sort before use it
                        if ( $permit eq '' ) {
                                delete $access_hash{$d}{$user};
                        }
                        else {
                                $access_hash{$d}{$user} = $permit;
                        }

                }
        }
        else {

                if ( exists $access_hash{$dir} ) {
                        print "in\n";
                        %user_permit_hash =
                          %{ $access_hash{$dir} };    #to use hash must put % before vars

                        if ( exists $user_permit_hash{$user} ) {
                                if ( $permit eq '' ) {
                                        delete $user_permit_hash{$user};

                                }
                                else {
                                        $user_permit_hash{$user} = $permit;
                                }

                        }
                        else {
                                if ( $permit ne '' ) {    #not equal '' do add
                                        $user_permit_hash{$user} = $permit;
                                }

                                #else do nothing
                        }

                        %{ $access_hash{$dir} } = %user_permit_hash;
                }
                else {    #add repository dir and user with that permit
                        $access_hash{$dir}{$user} = $permit;

                }
        }

}