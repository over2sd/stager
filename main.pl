#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Getopt::Long;
my $PROGNAME = 'Stager';
my $version = "0.1.11alpha";
my $conffilename = 'config.ini';
my $showhelp = 0;
my $debug = 0; # verblevel
sub howVerbose { return $debug; }

$|++;
GetOptions(
	'conf|c=s' => \$conffilename,
	'help|h' => \$showhelp,
	'verbose|v=i' => \$debug,
);
if ($showhelp) {
	print "$PROGNAME v$version\n";
	print "usage: main.pl -c [configfile]\n";
	print " -v #: set information verbosity level";
	print "All other options are controlled from within the GUI.\n";
	exit(0);
}
use lib "./modules/";
use Common;
use FIO;

FIO::loadConf($conffilename);
FIO::config('Debug','v',$debug);
Options::formatTooltips();
use FlexSQL;
use PGUI;
print "\n";
Common::errorOut('inline',0,string => "[I] Starting GUI...");
my $gui = PGK::createMainWin($PROGNAME,$version);
PGK::startwithDB($gui,$PROGNAME);

Prima->run();

print "\n";
