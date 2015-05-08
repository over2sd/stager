package FIO;

use Config::IniFiles;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw( config saveConf loadConf );
print __PACKAGE__;

my $cfg = Config::IniFiles->new();
my $cfgread = 0;

Common::registerErrors('FIO::config',"[W] Using empty configuration!");
sub config {
	my ($section,$key,$value) = @_;
	unless (defined $value) {
		unless ($cfgread) { Common::errorOut('FIO::config',1,fatal => 0) ; }
		if (defined $cfg->val($section,$key,undef)) {
			return $cfg->val($section,$key);
		} else {
			return undef;
		}
	} else {
		if (defined $cfg->val($section,$key,undef)) {
			return $cfg->setval($section,$key,$value);
		} else {
			return $cfg->newval($section,$key,$value);
		}
	}
}
print ".";

sub validateConfig { # sets config values for missing required defaults
	my %defaults = (
		"width" => 375,
		"height" => 480,
		"savepos" => 0
		);
	foreach (keys %defaults) {
		unless (config('Main',$_)) {
			config('Main',$_,$defaults{$_});
		}
	}
}
print ".";

sub saveConf {
	$cfg->RewriteConfig();
	$cfgread = 1; # If we're writing, I'll assume we have some values to use
}
print ".";

sub loadConf {
	my $configfilename = shift || "config.ini";
	$cfg->SetFileName($configfilename);
	print "Seeking configuration file...";
	if ( -s $configfilename ) {
		print "found. Loading...";
		$cfg->ReadConfig();
		$cfgread = 1;
	}
	validateConfig();
}
print ".";

sub gz_decom {
	my ($ifn,$ofn,$guiref) = @_;
	my $window = $$guiref{mainWin};
	use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
	sub gzfail { 
		PGUI::sayBox($window,$_);
		return 0;
		}
	gunzip($ifn => $ofn, Autoclose => 1)
		or gzfail($GunzipError);
	return 1;
}
# TODO: Check this function more thoroughly to see if it does what is expected.
print ".";

sub getFileName {
	my ($caller,$parent,$guir,$title,$action,$oktext,%filter) = @_;
	unless (defined $parent) { $parent = $$guir{mainWin}; }
	$$guir{status}->push("Choosing file...");
	my $filebox = Prima::OpenDialog->new(
		filter => %filter,
		fileMustExist => 1
	);
	my $filename = undef;
	if ($filebox->execute()) {
		$filename = $filebox->fileName;
	} else {
		$$guir{status}->push("File selection cancelled.");
	}
	$filebox->destroy();
	return $filename;
}
print ".";

print " OK; ";
1;
