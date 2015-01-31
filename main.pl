#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Getopt::Long;
my $version = "0.0.1prealpha";
my $conffilename = 'config.ini';
my $showhelp = 0;
GetOptions(
	'conf|c=s' => \$conffilename,
	'help|h' => \$showhelp,
);
if ($showhelp) {
	print "Stager v$version\n";
	print "usage: main.pl -c [configfile]\n";
	print "All other options are controlled from within the GUI.\n";
	exit(0);
}
use lib "./modules/";

# print "Loading modules...";

use FIO qw( loadConf );

FIO::loadConf($conffilename);
use FlexSQL;
use PGUI;
print "\nStarting GUI...\n";
my $gui = PGUI::createMainWin($version);
my $dbh = PGUI::loadDBwithSplashDetail($gui);
PGUI::populateMainWin($dbh,$gui);

print "GUI contains: " . join(", ",keys %$gui) . "\n";
Prima->run();

print "\n";
