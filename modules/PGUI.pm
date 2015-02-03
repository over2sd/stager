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
		size => [($w or 640),($h or 480)],
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

sub getTabByCode { # for definitively finding page ID of tabs...
	my $code = shift;
	my $tabs = (getGUI("tablist") or []);
	return Common::findIn($code,@$tabs);
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
	$text->push("Loading database config...");
	$prog->value(++$step/$steps*100);
	my $curstep = $box->insert( Label => text => "");
	unless (defined config('DB','type')) {
		$steps ++; # number of steps in type dialogue
		my $dbtype = undef;
		$text->push("Getting settings from user...");
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
		$text->push("Saving database type...");
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
			$text->push("Getting login credentials...");
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
			$text->push("Saving server info...");
			$prog->value(++$step/$steps*100); # 1
#			$uname = ($umand ? $uname : undef);
			config('DB','host',$host); config('DB','user',$uname); config('DB','password',$pmand);
		} else {
			$text->push("Using file as database...");
# TODO: Replace with SaveDialog to choose DB filename?
			config('DB','host','localfile'); # to prevent going through this branch every time
			$prog->value(++$step/$steps*100); # 0a
		}
		FIO::saveConf();
	}
	my ($uname,$host,$pw) = (config('DB','user',undef),config('DB','host',undef),config('DB','password',undef));
	# ask for password, if needed.
	my $passwd = ($pw =~ /[Yy]/ ? input_box("Login Credentials","Enter password for $uname\@$host:") : '');
	$curstep->text("Establish database connection.");
	$text->push("Connecting to database...");
	$prog->value(++$step/$steps*100);
	my ($dbh,$error) = FlexSQL::getDB($base,$host,'stager',$passwd,$uname);
	unless (defined $dbh) { # error handling
		Pdie("ERROR: $error");
		print "Exiting (no DB).\n";
	} else {
		$curstep->text("---");
		$text->push("Connected.");
	}
	if ($error =~ m/Unknown database/) { # rudimentary detection of first run
		$steps++;
		$curstep->text("Database not found. Attempting to initialize...");
		$text->text("Attempting to initialize database...");
		$prog->value(++$step/$steps*100);
		($dbh,$error) = FlexSQL::makeDB($base,$host,'stager',$passwd,$uname);
	}
	unless (defined $dbh) { # error handling
		Pdie("ERROR: $error");
		print "Exiting (no DB).\n";
	} else {
		$curstep->text("---");
		$text->text("Connected.");
	}
	unless (FlexSQL::table_exists($dbh,'work')) {
		$steps++;
		$prog->value(++$step/$steps*100);
		$text->text("Attempting to initialize database tables...");
		FlexSQL::makeTables($dbh);
	}
	$text->push("Done loading database.");
	$prog->value(++$step/$steps*100);
	if (0) { print "Splash screen steps: $step/$steps\n"; }
	$box->close();
	return $dbh;
}
print ".";

sub populateMainWin {
	my ($dbh,$gui,$refresh) = @_;
print ".";
	$$gui{status}->push(($refresh ? "Reb" : "B") . "uilding UI...");
# make a scrolled window
	my @tabtexts;
	my @tabs = qw[ mem rol ];
	foreach (@tabs) { # because tabs are controlled by option, tabnames must also be.
		if (/mem/) { push(@tabtexts,(config('Custom',$_) or "Members")); }
		elsif (/rol/) { push(@tabtexts,(config('Custom',$_) or "Roles")); }
	}
	$$gui{tablist} = \@tabs;
	my %args;
	if (defined config('UI','tabson')) { $args{orientation} = (config('UI','tabson') eq "bottom" ? tno::Bottom : tno::Top); } # set tab position based on config option
	$$gui{tabbar} = Prima::TabbedScrollNotebook->create(
		owner => getGUI("mainWin"),
		style => tns::Simple,
		tabs => \@tabtexts,
		name => 'Scroller',
		tabsetProfile => {colored => 0, %args, },
		pack => { fill => 'both', expand => 1, pady => 3, side => "left", },
	);
	$$gui{listpane} = $$gui{tabbar}->insert_to_page(0, VBox => name => "membox", pack => { fill => 'both' } );
	my $buttonbar = $$gui{listpane}->insert( HBox => name => 'buttons', pack => { side => "top", fill => 'x', expand => 0, }, );
	my $target = $$gui{listpane}->insert( VBox => name => "Members", pack => { fill => 'both', expand => 1, }, );
	$buttonbar->insert( Button =>
		text => "Add a member",
		onClick => sub { addMember($gui,$dbh,$target); },
		pack => { side => "right", fill => 'x', expand => 0, },
	);
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
				alignment => ta::Left,
				pack => { fill => 'x' },
				onClick => sub { showRoleEditor($gui,$dbh,$a[2]); }# link button to role editor
				);
			# TODO: use $a[2] (member ID) to count roles from roles table
		}
	}
	$$gui{rolepage} = $$gui{tabbar}->insert_to_page(1, VBox => name => "role details", pack => { fill => 'both', expand => 1, side => 'left', });
	my $memtext = (config("Custom",'mem') or "Members");
	$$gui{rolepage}->insert( Label => text => "Click on a member name on the $memtext page to fill this tab.", height => 60, pack => { fill => 'both', } );
	$$gui{status}->push("Ready.");
print " Done.";
}
print ".";

sub sayBox {
	my ($parent,$text) = @_;
	message($text,owner=>$parent);
}
print ".";

sub showRoleEditor {
	my ($gui,$dbh,$mid) = @_;
	$$gui{rolepage}->empty();
	my $loading = $$gui{rolepage}->insert( Label => text => "The info for ID #$mid is now loading..." );
	$$gui{tabbar}->pageIndex(1);
	#get info for given mid
	my $res = FlexSQL::getMemberByID($dbh,$mid);
	my %row = %$res;
	if (keys %row) {
	# list info
		my $nametxt = "Name: $row{givname} $row{famname}";
		my $meminfo = labelBox($$gui{rolepage},$nametxt,"Roles",'v');
		# TODO: member edit button
		if (config("UI","showcontact")) {
			$meminfo->insert( Label => text => "E-mail: $row{email}" );
			$meminfo->insert( Label => text => "Phone: $row{hphone} H $row{mphone} M" );
		}
		$meminfo->insert( Label => text => "Roles:", alignment => ta::Left, pack => { fill => 'x', });
		my $roletarget = $meminfo->insert( VBox => name => "rolebox", backColor => (convertColor(config('UI','rolebg') or "#99f")), pack => { fill => 'both', expand => 1, side => "left", padx => 5, pady => 5, }, );
	# get roles
	# list roles, with edit button for each role
	# place add role button
		my $addbutton = $meminfo->insert( Button => text => "Add a role", );
		$addbutton->onClick( sub { addRole($dbh, $mid, $roletarget, $addbutton); } );
	}
	$$gui{rolepage}->insert( Button => text => "Return", onClick =>  sub { $$gui{tabbar}->pageIndex(0); } );

	$loading->destroy();
}
print ".";

sub addMember {
	my ($gui,$dbh,$target) = @_;
	my $addbox = Prima::Dialog->create(
		borderStyle => bs::Sizeable,
		size => [400,400],
		text => "User Details",
		owner => $$gui{mainWin},
		onTop => 1,
	);
	$addbox->hide();
	$::application->yield();
	my $vbox = $addbox->insert( VBox => name => 'details', pack => { fill => 'both', expand => 1 } );
	$vbox->insert( Button =>
		text => "Cancel",
		onClick => sub { print "Cancelled"; $addbox->destroy(); },
	);
	my $namebox = $vbox->insert( HBox => name => 'namebox', pack => { expand => 1, }, );
	my $nbox1 = labelBox($namebox,"Given Name",'n1','v');
	my $nbox2 = labelBox($namebox,"Family Name",'n2','v');
	my $givname = $nbox1->insert( InputLine => maxLen => 23, text => '', );
	my $famname = $nbox2->insert( InputLine => maxLen => 28, text => '', );
	$vbox->insert( Label => text => "Home Phone" );
	my $hphone = $vbox->insert( InputLine => maxLen => 10, width => 150, text => '##########', );
	$vbox->insert( Label => text => "Mobile/Work Phone" );
	my $mphone = $vbox->insert( InputLine => maxLen => 10, width => 150, text => '##########', );
	$vbox->insert( Label => text => "E-mail Address" );
	my $email = $vbox->insert( InputLine => maxLen => 254, text => (config('InDef','email') or 'user@example.com'), pack => { fill => 'x', } );
	my $abox = labelBox($vbox,"Age (or A for adult 21+ )",'abox','h',boxfill => 'x');
# TODO: Add calendar button for date of birth? (if option selected?)
	my $age = $abox->insert( InputLine => maxLen => 3, width => 45, text => '', );
	$vbox->insert( Label => text => "Street Address" );
	my $address = $vbox->insert( InputLine => maxLen => 253, text => '', pack => { fill => 'x', } );
	my $cbox = $vbox->insert( HBox => name => 'citybox', pack => { expand => 1, }, );
	my $cbox1 = labelBox($cbox,"City",'c1','v',boxfill => 'x', labfill => 'x');
	my $cbox2 = labelBox($cbox,"State",'c2','v');
	my $cbox3 = labelBox($cbox,"ZIP",'c3','v');
	my $city = $cbox1->insert( InputLine => maxLen => 99, text => (config('InDef','city') or ''), pack => { fill => 'x', expand => 1} );
	my $state = $cbox2->insert( InputLine => maxLen => 3, text => (config('InDef','state') or ''), width => 45, );
	my $zip = $cbox3->insert( InputLine => maxLen => 10, text => (config('InDef','ZIP') or ''), );
# TODO: Add radio button for member types?
	my %user;
	$vbox->insert( Button =>
		text => "Add User",
		onClick => sub {
			$addbox->hide();
			# process information
			unless ($famname->text ne '' && $givname->text ne '') {
				sayBox($addbox,"Required fields: Family Name, Given Name");
				$addbox->show();
				return;
			}
			$user{famname} = $famname->text;
			$user{givname} = $givname->text;
			$user{hphone} = $hphone->text if ($hphone->text ne '##########');
			$user{mphone} = $mphone->text if ($mphone->text ne '##########');
			$user{email} = $email->text if ($email->text ne (config('InDef','email') or 'user@example.com'));
			$user{age} = $age->text if ($age->text ne '');
			$user{address} = $address->text if ($address->text ne '');
			$user{city} = $city->text if ($city->text ne '' && $address->text ne '');
			$user{state} = $state->text if ($state->text ne '' && $address->text ne '');
			$user{zip} = $zip->text if ($zip->text ne '' && $address->text ne '');
			$addbox->destroy();
			# store information
			my ($error,$cmd,@parms) = FlexSQL::prepareFromHash(\%user,'member',0);
			if ($error) { sayBox($$gui{mainWin},"Preparing user add statement failed: $error - $parms[0]"); return; }
			$error = FlexSQL::doQuery(2,$dbh,$cmd,@parms);
			unless ($error == 1) { sayBox($$gui{mainWin},"Adding user to database failed: $error"); return; }
			$cmd = "SELECT givname, famname, mid FROM member WHERE famname=? AND givname=?;";
			@parms = ($user{famname},$user{givname});
			my $res = FlexSQL::doQuery(4,$dbh,$cmd,@parms);
			unless (defined $res) {
				Pdie("Error: Database access yielded undef!");
			} else {
				foreach (@$res) {
					my @a = @$_;
					my $text = "$a[1], $a[0]"; # concatenate famname, givname and put a label in the window.
					my $button = $target->insert( Button =>
						text => $text,
						alignment => ta::Left,
						pack => { fill => 'x' },
						onClick => sub { showRoleEditor($gui,$dbh,$a[2]); }# link button to role editor
					);
				}
			}
		}
	);
	$addbox->show();
#	my $result = $addbox->execute();
}
print ".";

sub labelBox {
	my ($parent,$label,$name,$orientation,%args) = @_;
	my $box;
	unless (defined $orientation && $orientation =~ /[Hh]/) {
		$box = $parent->insert( VBox => name => "$name", pack => { fill => ($args{boxfill} or 'none'), expand => ($args{boxex} or 1) }, );
	} else {
		$box = $parent->insert( HBox => name => "$name", pack => { fill => ($args{boxfill} or 'none'), expand => ($args{boxex} or 1) }, );
	}
	$box->insert( Label => text => "$label", pack => { fill => ($args{labfill} or 'x'), expand => ($args{labex} or 0), }  );
	return $box;
}
print ".";

sub addRole {
	my ($dbh, $mid, $target,$button) = @_;
	$button->hide();
	my $editbox = $target->insert( HBox => name => 'roleadd', pack => { fill => 'x', expand => 0, }, );
	my $showbox = labelBox($editbox,"Production",'shobox','v',boxfill => 'x', boxex => 0, labex => 1);
	my $shows = FlexSQL::getShowList($dbh);
	my @showlist = values $shows;
	my $work = $showbox->insert( ComboBox => style => cs::DropDown, items => \@showlist, text => '', height => 30 );
	my $rolebox = labelBox($editbox,"Role",'rolbox','v',boxfill => 'x', labex => 1);
	my $role = $rolebox->insert( InputLine => text => '', pack => { fill => 'x' } );
	my $ybox = labelBox($editbox,"Year",'ybox','v',labex => 1);
	my $year = $ybox->insert( InputLine => text => '', width => 60, maxLen => 4 );
	my $mbox = labelBox($editbox,"Month",'mbox','v',labex => 1);
	my $month = $mbox->insert( InputLine => text => '', width => 30, maxLen => 2 );
	my $tbox = labelBox($editbox,"Troupe",'tbox','v', bocfill => 'x', labex => 1);
	my $troupes = FlexSQL::getTroupeList($dbh);
	my @troupelist = values $troupes;
	my $troupe = $tbox->insert( ComboBox => style => cs::DropDown, items => \@troupelist, text => '', height => 30 );
	my $submitter = $editbox->insert( Button => text => "Submit");
	$submitter->onClick( sub {
		my $sid = Common::revGet($work->text,undef,%$shows);
		my $tid = Common::revGet($troupe->text,undef,%$troupes);
		unless (defined $sid) {
			print "New show: " . $work->text . " will be added to database.\n";
			my $st = "INSERT INTO work (sname) VALUES(?);";
			my $res = FlexSQL::doQuery(2,$dbh,$st,$work->text);
			print "(not yet coded) ($res)";
			$st = "SELECT wid FROM work WHERE sname=?;";
			$res = FlexSQL::doQuery(0,$dbh,$st,$work->text);
			print "SID: $res\n";
			return;
		}
		unless (defined $tid) {
			print "New troupe: " . $troupe->text . " will be added to database.\n";
			my $st = "INSERT INTO troupe (tname) VALUES(?);";
			my $res = FlexSQL::doQuery(2,$dbh,$st,$troupe->text);
			print "(not yet coded) ($res)";
			$st = "SELECT tid FROM troupe WHERE tname=?;";
			$res = FlexSQL::doQuery(0,$dbh,$st,$troupe->text);
			print "TID: $res\n";
			return;
		}
		print "-> " . ($sid or "undef") . ": " . $role->text . " (" . ($tid or "undef") . ", " . $month->text . "/" . $year->text . ")";
		$button->show();
		$editbox->destroy();
		$submitter->destroy();
	} );
print "Loading of roles for member #$mid is not yet coded.\n";
}
print ".";

sub showRole {
	my ($target,$rid,$sid,$tid,$role,$y,$m) = @_;
	my $tname = FlexSQL::getTroupeByID($tid);
	my $sname = FlexSQL::getShowByID($sid);
	my $row = labelBox($target,"$sname: $role ($tname, $m/$y)",'h');
	my $editbut = $row->insert( Button => text => "Edit role ($rid)" );
# replace this with a row builder that puts the role and an edit button in a row in the target.
	return 0;
}
print ".";

sub storeNewRole {
	my ($dbh,$sid,$tid,$y,$m,$role,$target) = @_;

}
print ".";

print " OK; ";
1;
