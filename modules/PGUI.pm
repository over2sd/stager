# Graphic User Interface module
use strict; use warnings;
package PGUI;
print __PACKAGE__;

my $PROGNAME = 'Stager';

use Prima qw(Application Buttons MsgBox FrameSet StdDlg Sliders Notebooks ScrollWidget);
$::wantUnicodeInput = 1;

use GK qw( VBox Table );

use FIO qw( config );

sub Pdie {
	my $message = shift;
	my $w = getGUI('mainWin');
	message_box("Fatal Error",$message,mb::Yes | mb::Error);
	$w->close();
	exit(-1);
}

sub Pwait {
	# Placeholder for if I ever figure out how to do a non-blocking sleep function in Prima
}

sub buildMenus { #Replaces Gtk2::Menu, Gtk2::MenuBar, Gtk2::MenuItem
	my $self = shift;
	my $menus = [
		[ '~File' => [
#			['~Import', 'Ctrl-O', '^O', sub { importGUI() } ],
#			['~Export', sub { message('export!') }],
#			['~Synchronize', 'Ctrl-S', '^S', sub { message('synch!') }],
#			['~Preferences', \&callOptBox],
			[],
			['Close', 'Ctrl-W', km::Ctrl | ord('W'), sub { $self->close() } ],
		]],
		[ '~Help' => [
			['~About',sub { message('About!') }], #\&aboutBox],
		]],
	];
	return $menus;
}
print ".";

sub convertColor {
	my ($color,$force) = @_;
	return undef unless (defined $color); # undef if no color given
	return $color unless ($force or $color =~ m/^#/); # return color unchanged unless it starts with '#' (allows passing integer straight through, as saveConf is going to write it as int, but we want user to be able to write it as #ccf).
	return ColorRow::stringToColor($color); # convert e.g. "#ccf" to integer needed by Prima
}
print ".";

my %windowset;

sub createMainWin {
	my ($version,$w,$h) = @_;
	my $window = Prima::MainWindow->new(
		text => (config('Custom','program') or "$PROGNAME") . " v.$version",
		size => [($w or 750),($h or 550)],
	);
	if (config('Main','savepos')) {
		unless ($w and $h) { $w = config('Main','width'); $h = config('Main','height'); }
		$window->size($w,$h);
		$window->place( x => (config('Main','left') or 40), rely => 1, y=> -(config('Main','top') or 30), anchor => "nw");
	}
	$window->set( menuItems => buildMenus($window));

	#pack it all into the hash for main program use
	$windowset{mainWin} = $window;
	$windowset{status} = getStatus($window);
	return \%windowset;
}
print ".";

sub createSplash {
	my $window = shift;
	my $vb = $window->insert( VBox => name => "splashbox", pack => { anchor => "n", fill => 'x', expand => 0, relx => 0.5, rely => 0.5, padx => 5, pady => 5, }, );
	my $label = $vb->insert( Label => text => "Loading $PROGNAME...", pack => { fill=> "x", expand => 0, side => "left", relx => 0.5, padx => 5, pady => 5,},);
	my $progress = $vb->insert( Gauge =>
		value => 0,	
		relief => gr::Raise,
		height => 35,
		pack => { fill => 'x', expand => 0, padx => 3, side => "left", },
	);
	return $progress,$vb;
}
print ".";

sub getGUI {
	unless (defined keys %windowset) { createMainWin(); }
	my $key = shift;
	if (defined $key) {
		if (exists $windowset{$key}) {
			return $windowset{$key};
		} else {
			return undef;
		}
	}
	return \%windowset;
}
print ".";

my $status = undef;
sub getStatus {
	my $win = shift;
	unless(defined $status) {
		unless (defined $win) { $win = getGUI(); }
		$status = StatusBar->new(owner => $win)->prepare();
	}
	return $status;
}
print ".";

sub getTabByCode { # for definitively finding page ID of recent, suggested tabs...
	my $code = shift;
	my $tabs = (getGUI("tablist") or []);
	return Common::findIn($code,@$tabs);
}
print ".";

sub importGUI {
	use Import qw( importXML );
	my $gui = getGUI();
	my $dbh = FlexSQL::getDB();
	### Later, put selection here for type of import to make
	# For now, just allowing import of XML file
	return Import::importXML($dbh,$gui);
}
print ".";

sub loadDBwithSplashDetail {
	my $gui = shift;
	my ($prog,$box) = createSplash($$gui{mainWin});
	my $text = $$gui{status};
	# do stuff using this window...
	my $pulse = 0;
	my $steps = 4;
	my $step = 0;
	my $base = "";
	$text->text("Loading database config...");
	$prog->value(++$step/$steps*100);
	my $curstep = $box->insert( Label => text => "");
	unless (defined config('DB','type')) {
		$steps ++; # number of steps in type dialogue
		my $dbtype = undef;
		$text->text("Getting settings from user...");
		$prog->value(++$step/$steps*100); # 0 (matches else)
		my $result = message("Choose database type:",mb::Cancel | mb::Yes | mb::No,
			buttons => {
					mb::Yes, {
						text => "MySQL", hint => "Use if you have a MySQL database.",
					},
					mb::No, {
						text => "SQLite", hint => "Use if you can't use MySQL.",
					},
					mb::Cancel, {
						text => "Quit", hint => "Abort loading the program (until you set up your database?)",
					},
			}
		);
		if ($result == mb::Yes) {
			$dbtype = 'M';
		} elsif ($result == mb::No) {
			$dbtype = 'L';
		} else {
			print "Exiting (abort).\n";
			$$gui{mainWin}->close();
		}
		$text->text("Saving database type...");
		$prog->value(++$step/$steps*100);
		# push DB type back to config, as well as all other DB information, if applicable.
		config('DB','type',$dbtype);
		$base = $dbtype;
	} else {
		$curstep->text("Using configured database type.");
		$prog->value(++$step/$steps*100);
		$base = config('DB','type');
	}
	unless (defined config('DB','host')) {
		$steps ++; # host
		# unless type is SQLite:
		unless ($base eq 'L') {
			$steps ++; # type dialogue
			$curstep->text("Enter database login info");
			$text->text("Getting login credentials...");
			$prog->value(++$step/$steps*100); # 0
		# ask user for host
			my $host = input_box("Server Info","Server address:","127.0.0.1");
		# ask user if username required
			my $umand = (message("Username required?",mb::YesNo) == mb::Yes ? 'y' : 'n');
		# ask user for SQL username, if needed by server (might not be, for localhost)
			my $uname = ($umand eq 'y' ? input_box("Login Credentials","Username (if required)","") : undef);
		# ask user if password required
			my $pmand = (message("Password required?",mb::YesNo) == mb::Yes ? 'y' : 'n');
			$curstep->text("---");
			# save data from entry boxes...
			$text->text("Saving server info...");
			$prog->value(++$step/$steps*100); # 1
#			$uname = ($umand ? $uname : undef);
			config('DB','host',$host); config('DB','user',$uname); config('DB','password',$pmand);
		} else {
			$text->text("Using file as database...");
			config('DB','host','localfile'); # to prevent going through this branch every time
			$prog->value(++$step/$steps*100); # 0a
		}
		FIO::saveConf();
	}
	my ($uname,$host,$pw) = (config('DB','user',undef),config('DB','host',undef),config('DB','password',undef));
	# ask for password, if needed.
	my $passwd = ($pw =~ /[Yy]/ ? input_box("Login Credentials","Enter password for $uname\@$host:") : '');
	$curstep->text("Establish database connection.");
	$text->text("Connecting to database...");
	$prog->value(++$step/$steps*100);
	my ($dbh,$error) = FlexSQL::getDB($base,$host,'stager',$passwd,$uname);
	unless (defined $dbh) { # error handling
		Pdie("ERROR: $error");
		print "Exiting (no DB).\n";
	} else {
		$curstep->text("---");
		$text->text("Connected.");
	}
	$text->text("Done loading database.");
	$prog->value(++$step/$steps*100);
	if (0) { print "Splash screen steps: $step/$steps\n"; }
	$box->close();
	return $dbh;
}
print ".";

sub populateMainWin {
	my ($dbh,$gui,$refresh) = @_;
print ".";
	$$gui{status}->text(($refresh ? "Reb" : "B") . "uilding UI...");
# make a scrolled window
	$$gui{listpane} = $$gui{mainWin}->insert( ScrollWidget => name => "Scroller" );
	my $target = $$gui{listpane}->insert( VBox => name => "Members", pack => { fill => 'both', expand => 1, }, );
# Pull records from DB
	my $res = FlexSQL::getMembers($dbh,'all',());
# foreach record:
	unless (defined $res) {
		Pdie("Error: Database access yielded undef!");
	} else {
		foreach (@$res) {
			my @a = @$_;
			my $text = "$a[1], $a[0]"; # concatenate famname, givname and put a label in the window.
			my $button = $target->insert( Button =>
				text => $text,
				onClick => sub { showRoleEditor($$gui{mainWin},$dbh,$a[2]); }# link button to role editor
				);
			# TODO: use $a[2] (member ID) to count roles from roles table
		}
	}
print "Nothing";
	$$gui{status}->text("Ready.");
print " Done.";
}
print ".";

sub sayBox {
	my ($parent,$text) = @_;
	message($text,owner=>$parent);
}
print ".";

sub showRoleEditor {
#	$$gui{mainWin},$dbh,$_[2]
	my ($parent,$dbh,$mid) = @_;
	sayBox($parent,"This function hasn't been coded yet. (ID: $mid)");
}
print ".";

print " OK; ";
1;
