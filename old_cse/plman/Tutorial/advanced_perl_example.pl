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

print "md5 test: " . md5_hex("test") . "\n";
if( md5_hex("test")."" ne "098f6bcd4621d373cade4e832627b4f6" ){
    die "incorrect md5 implementation?\n";
}

# the config file containing your username and password, make sure this file is chmod 600
my $config = "/Users/colin/Desktop/PlMan/pl_manager.conf";
my $auth   = readConfig($config);
$auth = md5Auth($auth);

my $url = "http://127.0.0.1:8088/xmlrpc";

my $client = Frontier::Client->new( url => $url, debug => 0, );

# *******************
# * COMMAND SECTION *
# *******************

# **************
# * PARAMETERS *
# **************

my @nodeNames;
my @nodeIPs;
my @intrIPs;
my @intrPorts;
my $sendIP;
my $sendPort;
my $recvIP;
my $recvPort;
my $numInts = 20;

my $intrPort = 5017;

if( $#ARGV != 5 ){
    die "args: <sendIP> <sendPort> <recvIP> <recvPort> <nodeNamesFile> <nodeIPsFile>\n";
}

# *******************
# * READ PARAMETERS *
# *******************

$sendIP = $ARGV[0];
$sendPort = $ARGV[1];
$recvIP = $ARGV[2];
$recvPort = $ARGV[3];

#choose some number of random hosts from intermediary list
my $nodeIPsFile;
my $nodeNamesFile;
open( $nodeNamesFile, $ARGV[4] ) or die "cannot open node name list $ARGV[4]\n";
open( $nodeIPsFile, $ARGV[5] ) or die "cannot open node IP list $ARGV[5]\n";
@nodeNames = <$nodeNamesFile>;
@nodeIPs = <$nodeIPsFile>;
close( $nodeNamesFile );
close( $nodeIPsFile );
foreach my $i(0..$#nodeNames){
    chomp $nodeNames[$i];
    chomp $nodeIPs[$i];
}
my $curr;
foreach $i(0..($numInts-1)){
    $curr = int(rand($#nodeIPs+1));
    $intrIPs[$i] = $nodeIPs[$curr];
    $intrPorts[$i] = $intrPort;
}

# *****************
# * FHIP COMMANDS *
# *****************

## connect to 20 random hosts
#my $result = $client->call( 'PlanetLab.addRandomHostsFromPLC', $auth, 20 );

#connect to randomly chosen hosts
foreach my $intr(@intrIPs){
    my $result = $client->call( 'PlanetLab.connectToHost', $auth, $intr );
}

my $timeout;
my $command;
my $commandId;

# mirror a local directory, stop on error
#instead upload everything out of band
#my $mirror_dir = "/Users/colin/Desktop/linuxbin";
#my $timeout    = 60.1;
#my $mirror_result = $client->call( 'PlanetLab.upload', $auth, $mirror_dir, $timeout, 1 );

#intermediary commands
$timeout = 5.5;
$command = "cd linuxbin";
$commandId = $client->call( 'PlanetLab.queueCommand', $auth, $command, $timeout, 1 );
$command = "chmod u+x *";
$commandId = $client->call( 'PlanetLab.queueCommand', $auth, $command, $timeout, 1 );

$timeout = 500000.1;    #infinite timeout
$command = "./intermediary $intrPort 1 > /dev/null";
$commandId = $client->call( 'PlanetLab.queueCommand', $auth, $command, $timeout, 1 );

#receiver command
$command = "./linuxbin/receiver $recvPort ";
foreach $intr(0..$#intrIPs){
    $command = $command."$intrIPs[$intr] $intrPorts[$intr] ";
}
$command = $command."> /dev/null";
psystem( "ssh -fi ~/.ssh/id_rsa uw_dos\@$recvIP \"$command\"" );

#sleep for a while until intermediaries/sender are up
sleep( 60 );

#sender command
$command = "./linuxbin/sender $sendPort $recvIP $recvPort ";
foreach $intr(0..$#intrIPs){
    $command = $command."$intrIPs[$intr] $intrPorts[$intr] ";
}
$command = $command."> send.log";
psystem( "ssh -i ~/.ssh/id_rsa uw_dos\@$sendIP \"$command\"" );

#collect data from sender
psystem( "scp -i ~/.ssh/id_rsa uw_dos\@$sendIP:\"~/send.log\" $sendIP.log" );

#start cleaning up
#kill receiver
psystem( "ssh -i ~/.ssh/id_rsa uw_dos\@$recvIP killall -9 receiver" );

#kill all intermediaries
my $hosts = $client->call( 'PlanetLab.getConnectedHosts', $auth );
foreach my $host(@{$hosts}){
    psystem( "ssh -i ~/.ssh/id_rsa uw_dos\@$host killall -9 intermediary" );
}

# *******************
# * SAME SITE 1-HOP *
# *******************

my $sendName = getName( $sendIP );
my $intSameSiteName = getHostFromSameSite( $sendName );
my $intSameSiteIP = getIP( $intSameSiteName );

if( $intSameSiteName ne "" ){

#run the receiver
    $command = "./linuxbin/receiver $recvPort $intSameSiteIP $intrPort > /dev/null";
    psystem( "ssh -fi ~/.ssh/id_rsa uw_dos\@$recvIP \"$command\"" );

#run the intermediary
    $command = "./linuxbin/intermediary $intrPort 1 > /dev/null";
    psystem( "ssh -fi ~/.ssh/id_rsa uw_dos\@$intSameSiteIP \"$command\"" );

    sleep( 10 ); #wait for intermediary/receiver to start

#run the sender
    $command = "./linuxbin/sender $sendPort $recvIP $recvPort $intSameSiteIP $intrPort > hop-send.log";
    psystem( "ssh -i ~/.ssh/id_rsa uw_dos\@$sendIP \"$command\"" );

#collect data
    psystem( "scp -i ~/.ssh/id_rsa uw_dos\@$sendIP:~/hop-send.log hop-$sendIP.log" );

#kill receiver/intermediary
    psystem( "ssh -i ~/.ssh/id_rsa uw_dos\@$recvIP killall -9 receiver" );
    psystem( "ssh -i ~/.ssh/id_rsa uw_dos\@$intSameSiteIP killall -9 intermediary" );

}

# ************************
# * UNDERLAY EXPERIMENTS *
# ************************

#receiver command
$command = "./linuxbin/underlay_receiver $recvPort > /dev/null";
psystem( "ssh -fi ~/.ssh/id_rsa uw_dos\@$recvIP \"$command\"" );

#sleep for a while until receiver is up
sleep( 10 );

#sender command
$command = "./linuxbin/underlay_sender $sendPort $recvIP $recvPort > usend.log";
psystem( "ssh -i ~/.ssh/id_rsa uw_dos\@$sendIP \"$command\"" );

#collect data from sender
psystem( "scp -i ~/.ssh/id_rsa uw_dos\@$sendIP:\"~/usend.log\" und-$sendIP.log" );

#kill receiver
psystem( "ssh -i ~/.ssh/id_rsa uw_dos\@$recvIP killall -9 underlay_receiver" );

# ***********************
# * END COMMAND SECTION *
# ***********************

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

sub psystem{
    print $_[0]."\n";
    system $_[0];
}

sub getHostFromSameSite{
    my $suffix = substr $_[0], index( $_[0], "." );
    $suffix =~ s/\./\\\./g;
    foreach my $node(@nodeNames){
	if( $node =~ m/$suffix$/ and $node ne $_[0] ){
	    return $node;
	}
    }
}

sub getIP{
    foreach my $i(0..$#nodeNames){
	if( $nodeNames[$i] eq $_[0] ){
	    return $nodeIPs[$i];
	}
    }
}

sub getName{
    foreach my $i(0..$#nodeIPs){
	if( $nodeIPs[$i] eq $_[0] ){
	    return $nodeNames[$i];
	}
    }
}
