# Graphic User Interface module
use strict; use warnings;
package PGUI;
print __PACKAGE__;

my $PROGNAME = 'Stager';

use Prima qw(Application Buttons MsgBox FrameSet StdDlg Sliders Notebooks ScrollWidget);
$::wantUnicodeInput = 1;

use GK qw( VBox Table );

use FIO qw( config );
#use Options;

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
	my $gui = shift;
	my $menus = [
		[ '~File' => [
#			['~Export', sub { message('export!') }],
#			['~Synchronize', 'Ctrl-S', '^S', sub { message('synch!') }],
#			['~Preferences', sub { Options::mkOptBox($gui,getOpts()); }],
			[],
			['Close', 'Ctrl-W', km::Ctrl | ord('W'), sub { $$gui{mainWin}->close() } ],
		]],
		[ '~Help' => [
			['~About', \&aboutBox],
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
	$windowset{mainWin} = $window;
	$window->set( menuItems => buildMenus(\%windowset));

	#pack it all into the hash for main program use
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
	$$gui{status}->push(($refresh ? "Reb" : "B") . "uilding UI...");
# make a scrolled window
	my @tabtexts;
	my @tabs = qw[ mem rol ];
	push(@tabs,'sho') if config('UI','showprodlist');
	foreach (@tabs) { # because tabs are controlled by option, tabnames must also be.
		if (/mem/) { push(@tabtexts,(config('Custom',$_) or "Members")); }
		elsif (/rol/) { push(@tabtexts,(config('Custom',$_) or "Roles")); }
		elsif (/sho/) { push(@tabtexts,(config('Custom',$_) or "Show")); }
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
			print ".";
			my @a = @$_;
			# TODO: use $a[2] (member ID) to count roles from roles table
			my $text = "$a[1], $a[0]"; # concatenate famname, givname and put a label in the window.
			my $button = $target->insert( Button =>
				text => $text,
				alignment => ta::Left,
				pack => { fill => 'x' },
				onClick => sub { showRoleEditor($gui,$dbh,$a[2]); }# link button to role editor
				);
		}
	}
	$$gui{rolepage} = $$gui{tabbar}->insert_to_page(1, VBox => name => "role details", pack => { fill => 'both', expand => 1, side => 'left', });
	my $memtext = (config("Custom",'mem') or "Members");
	$$gui{rolepage}->insert( Label => text => "Click on a member name on the $memtext page to fill this tab.", height => 60, pack => { fill => 'both', } );
	if (config('UI','showprodlist')) {
		$$gui{prodpage} = $$gui{tabbar}->insert_to_page(2, VBox => name => "show cast list", pack => { fill => 'both', expand => 1, side => 'left', });
		my $selshowrow = labelBox($$gui{prodpage},"Select show and troupe:",'selbox','h', boxfill => 'x', boxex => 0,);
		my $shows = FlexSQL::getShowList($dbh);
		my @showlist = values $shows;
		my $work = $selshowrow->insert( ComboBox => style => cs::DropDown, items => \@showlist, text => '', height => 30 );
		my $troupes = FlexSQL::getTroupeList($dbh);
		my @troupelist = values $troupes;
		my $troupe = $selshowrow->insert( ComboBox => style => cs::DropDown, items => \@troupelist, text => (config('InDef','troupe') or ''), height => 30 );
		my $castlist = $$gui{prodpage}-> insert( VBox => name => 'castbox', pack => { fill => 'both', expand => 0, });
		$selshowrow->insert( Button => text => "Show Cast/Crew", onClick => sub { my $sid = Common::revGet($work->text,undef,%$shows); my $tid = Common::revGet($troupe->text,undef,%$troupes); castShow($dbh,$castlist,$sid,$tid); } );
	}
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
	my $res = FlexSQL::getMemberByID($dbh,$mid); #get info for given mid
	my %row = %$res;
	if (keys %row) {
		# list info
		my $nametxt = "Name: $row{givname} $row{famname}";
		my $meminfo = labelBox($$gui{rolepage},$nametxt,"Roles",'v');
		$meminfo->insert( Button => text => "Edit", onClick => sub { devHelp($meminfo,"Editing of member information"); } );
		# TODO: member edit button
		if (config("UI","showcontact")) {
			$meminfo->insert( Label => text => "E-mail: $row{email}" );
			$meminfo->insert( Label => text => "Phone: $row{hphone} H $row{mphone} M" );
		}
		$meminfo->insert( Label => text => "Roles:", alignment => ta::Left, pack => { fill => 'x', });
		my $roletarget = $meminfo->insert( VBox => name => "rolebox", backColor => (convertColor(config('UI','rolebg') or "#99f")), pack => { fill => 'both', expand => 1, side => "left", padx => 5, pady => 5, }, );
		my $st = "SELECT * FROM cv WHERE mid=?"; # get roles
		my $res = FlexSQL::doQuery(3,$dbh,$st,$mid,'rid');
		foreach (keys %$res) { # list roles, with edit button for each role
			my %row = %{ $$res{$_} };
			showRole($dbh,$roletarget,$row{rid},$row{work},$row{troupe},$row{role},$row{year},$row{month});
		}
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
	my $tbox = labelBox($editbox,"Troupe",'tbox','v', boxfill => 'x', labex => 1);
	my $troupes = FlexSQL::getTroupeList($dbh);
	my @troupelist = values $troupes;
	my $troupe = $tbox->insert( ComboBox => style => cs::DropDown, items => \@troupelist, text => (config('InDef','troupe') or ''), height => 30 );
	my $submitter = $editbox->insert( Button => text => "Submit");
	$submitter->onClick( sub {
		my $sid = Common::revGet($work->text,undef,%$shows);
		my $tid = Common::revGet($troupe->text,undef,%$troupes);
		unless (defined $sid) {
			print "New show: " . $work->text . " will be added to database.\n";
			my $st = "INSERT INTO work (sname) VALUES(?);";
			my $res = FlexSQL::doQuery(2,$dbh,$st,$work->text);
			$st = "SELECT wid FROM work WHERE sname=?;";
			$res = FlexSQL::doQuery(0,$dbh,$st,$work->text);
			$sid = $res unless ($DBI::err);
		}
		unless (defined $tid) {
			print "New troupe: " . $troupe->text . " will be added to database.\n";
			my $st = "INSERT INTO troupe (tname) VALUES(?);";
			my $res = FlexSQL::doQuery(2,$dbh,$st,$troupe->text);
			$st = "SELECT tid FROM troupe WHERE tname=?;";
			$res = FlexSQL::doQuery(0,$dbh,$st,$troupe->text);
			$tid = $res unless ($DBI::err);
		}
#		print "-> " . ($sid or "undef") . ": " . $role->text . " (" . ($tid or "undef") . ", " . $month->text . "/" . $year->text . ")";
		if (defined $sid and defined $tid) {
			storeNewRole($dbh,$mid,$sid,$tid,$year->text,$month->text,$role->text,$target);
		} else {
			sayBox($editbox,"Something went wrong storing the role.");
		}
		$button->show();
		$editbox->destroy();
		$submitter->destroy();
	} );
}
print ".";

sub showRole {
	my ($dbh,$target,$rid,$sid,$tid,$role,$y,$m) = @_;
	my $tname = FlexSQL::getTroupeByID($dbh,$tid);
	my $sname = FlexSQL::getShowByID($dbh,$sid);
	my $row = labelBox($target,"$sname: $role ($tname, $m/$y)",'rolerow','h', boxfill => 'x', labfill => 'none');
	$row->backColor(convertColor(config('UI','rolebg') or "#99f"));
	my $editbut = $row->insert( Button => text => "Edit role", onClick => sub { devHelp($target,"Editing of roles"); } );
	return 0;
}
print ".";

sub storeNewRole {
	my ($dbh,$mid,$sid,$tid,$y,$m,$role,$target) = @_;
	my @parms = ($mid,$sid,$tid,$y,$m,$role);
	my $st = "INSERT INTO cv (mid,work,troupe,year,month,role) VALUES(?,?,?,?,?,?);";
	my $res = FlexSQL::doQuery(2,$dbh,$st,@parms);
	$st = "SELECT rid FROM cv WHERE mid=? AND work=? AND troupe=? AND year=? AND month=? AND role=?;";
	$res = FlexSQL::doQuery(0,$dbh,$st,@parms);
	unless ($DBI::err) {
		showRole($dbh,$target,$res,$sid,$tid,$role,$y,$m);
	} else {
		sayBox($target,"An error occurred: $DBI::errstr");
	}
}
print ".";

sub aboutBox {
	my $w = getGUI('mainWin');
	sayBox($w,"Stager is a membership tracking program intended for community theatre troupes. If there's anything you'd like to see added to the program, let the developer know.");
}
print ".";

sub devHelp {
	my ($target,$task) = shift;
	sayBox($target,"$task is on the developer's TODO list.\nIf you'd like to help, check out the project's GitHub repo at http://github.com/over2sd/stager.");
}
print ".";

sub castShow {
	my ($dbh,$target,$sid,$tid) = @_;
	$target->empty(); # VBox function, clear list
	$target->insert( Label => text => "Cast/crew of a " . FlexSQL::getTroupeByID($dbh,$tid) . " production of " . FlexSQL::getShowByID($dbh,$sid) . ":" );
	my $st = "SELECT mid,role FROM cv WHERE work=? AND troupe=? ;";
	unless (defined $sid and defined $tid) { $target->insert( Label => text => "An error occurred: Invalid role or troupe given.\nIDs could not be secured for both values.", wordWrap => 1, height => 60, pack => { fill => 'both' }, ); return; }
	my @parms = ($sid,$tid);
	my $res = FlexSQL::doQuery(4,$dbh,$st,@parms);
	foreach (@$res) {
		my $mid = $$_[0];
		my $name = getMemNameByID($dbh,$mid);
		my $row = labelBox($target,"$$_[1]: ",'row','h');
		my $gui = getGUI();
		$row->insert( Button => text => $name, onClick => sub { showRoleEditor($gui,$dbh,$mid); } );
	}
}
print ".";

sub getMemNameByID {
	my ($dbh,$mid) = @_;
	my $text;
	my $st = "SELECT givname,famname FROM member WHERE mid=?;";
	my $res = FlexSQL::doQuery(6,$dbh,$st,$mid);
	return '' unless defined $res;
	# TODO?: add a column allowing name order to be stored for i18n?
	$text = "$$res{givname} $$res{famname}";
	return $text;
}
print ".";

sub getOpts {
	# First hash key (when sorted) MUST be a label containing a key that corresponds to the INI Section for the options that follow it!
	# EACH Section needs a label conaining the Section name in the INI file where it resides.
	my %opts = (
		'000' => ['l',"General",'Main'],
		'001' => ['c',"Save window positions",'savepos'],
##		'002' => ['x',"Foreground color: ",'fgcol',"#00000"],
##		'003' => ['x',"Background color: ",'bgcol',"#CCCCCC"],
		'004' => ['c',"Errors are fatal",'fatalerr'],

		'005' => ['l',"Import/Export",'ImEx'],

		'010' => ['l',"Database",'DB'],
		'011' => ['r',"Database type:",'type',0,'M','MySQL','L','SQLite'],
		'012' => ['t',"Server address:",'host'],
		'013' => ['t',"Login name (if required):",'user'],
		'014' => ['c',"Server requires password",'password'],
##		'019' => ['r',"Conservation priority",'conserve',0,'mem',"Memory",'net',"Network traffic (requires synchronization)"],

		'030' => ['l',"User Interface",'UI'],
		'032' => ['c',"Show production tab",'showprodlist'],
		'031' => ['s',"Notebook tab position: ",'tabson',1,"left","top","right","bottom"],
		'033' => ['c',"Show member contact in role listing",'showcontact'],
		'043' => ['x',"Background for role list",'rolebg',"#EEF"],

#		'050' => ['l',"Fonts",'Font'],
#		'054' => ['f',"Tab font/size: ",'label'],
#		'051' => ['f',"General font/size: ",'body'],
#		'053' => ['f',"Special font/size: ",'special'], # for lack of a better term

		'060' => ['l',"Input Defaults",'InDef'],
		'061' => ['t',"Troupe/Theatre:",'troupe'],
		'062' => ['t',"City:",'city'],
		'063' => ['t',"State:",'state'],
		'064' => ['t',"Postal Code:",'ZIP'],
		'065' => ['t',"E-mail:",'email'],

		'070' => ['l',"Custom Text",'Custom'],
		'072' => ['t',"Members:",'mem'],
		'073' => ['t',"Role:",'rol'],
		'071' => ['t',"Stager:",'program'],
		'074' => ['t',"Show:",'sho'],
		'076' => ['t',"Options dialog",'options'],

		'ff0' => ['l',"Debug Options",'Debug'],
		'ff1' => ['c',"Colored terminal output",'termcolors']
	);
	return %opts;
}
print ".";

sub refreshUI {
	print "Refreshing UI...(does nothing yet)\n";
}
print ".";

print " OK; ";
1;
