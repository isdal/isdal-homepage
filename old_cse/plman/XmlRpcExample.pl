#!/usr/bin/perl 
# Testing the XML-RPC api

use strict;
use warnings;
use Frontier::Client;

# import md5 library
BEGIN {
	eval {
		require Digest::MD5;
		import Digest::MD5 'md5_hex';
	};
	if ($@) {    # ups, no Digest::MD5
		require Digest::Perl::MD5;
		import Digest::Perl::MD5 'md5_hex';
	}
}

print "md5 test: " . md5_hex("test");

# the config file containing your username and password, make sure this file is chmod 600
my $config = "/Users/isdal/Documents/work/uw/planetlab_manager/pl_manager.conf";
my $auth   = readConfig($config);
$auth = md5Auth($auth);

my $url = "http://127.0.0.1:8088/xmlrpc";

my $client = Frontier::Client->new(
	url   => $url,
	debug => 0,
);

## connect to 10 random hosts
my $result = $client->call( 'PlanetLab.addRandomSitesFromPLC', $auth, 20 );

# mirror a local directory, stop on error
my $mirror_dir = "/Users/isdal/Documents/work/uw/planetlab_manager/mirror_dir";
my $timeout    = 60.1;
my $mirror_result = $client->call( 'PlanetLab.uploadDirectory',
	$auth, $mirror_dir, $timeout, 1 );

## ping jermaine, short timeout, stop on error

$timeout = 1.5;    #kill the command after 0.8 s

my $command = "ping -c 1 jermaine.cs.washington.edu";

my $commandId =
  $client->call( 'PlanetLab.queueCommand', $auth, $command, $timeout,
	1 );

# run the next command
$command   = "ps aux | wc";
$commandId = $client->call( 'PlanetLab.queueCommand', $auth, $command );

## wait for the command to complete
while (
	1.0 != $client->call( 'PlanetLab.commandCompleted', $auth, $commandId ) )
{
	sleep 1;

}

print "completed ";

## get output
my $exitcodes;
$exitcodes = $client->call( 'PlanetLab.getExitStats', $auth, $commandId );
print $exitcodes->{0};

### make the values less clear text
sub md5Auth {
	my $auth = $_[0];

	my $user_pass;
	$user_pass->{"Username"} = md5_hex($auth->{"Username"});
	#print $auth->{"Username"};
	$user_pass->{"AuthString"} = md5_hex($auth->{"Username"} . $auth->{"AuthString"});
	#$user_pass->{"Slice"} = $auth->{"Slice"};
	return $user_pass;
}
###read the configfile for authentication
sub readConfig {
	open( CONFIGFILE, $_[0] ) || die "Cannot read file $_[0]\n";

	my (@configMemoryImage) = <CONFIGFILE>;
	close(CONFIGFILE);

	my $auth;

	foreach my $configLine (@configMemoryImage) {
		chomp $configLine;
		if ( length($configLine) > 1 ) {
			my @split = split( '=', $configLine );
			if ( index( $split[0], "#" ) == -1 ) {
				my $key = ( $split[0] );
				my $value = ( substr( $configLine, length($key) + 1 ) );
				$auth->{$key} = $value;
			}
		}
	}
	return $auth;
}
