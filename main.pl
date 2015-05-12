#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use Getopt::Long;
my $version = "0.1.03alpha";
my $conffilename = 'config.ini';
my $showhelp = 0;
$|++;
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
use Common;
use FIO qw( loadConf );

FIO::loadConf($conffilename);
Options::formatTooltips();
use FlexSQL;
use PGUI;
print "\n";
Common::errorOut('inline',0,string => "[I] Starting GUI...");
my $gui = PGUI::createMainWin($version);
PGUI::start($gui);

print "GUI contains: " . join(", ",keys %$gui) . "\n";
Prima->run();

print "\n";
