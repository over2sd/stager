# Graphic User Interface module
use strict; use warnings;
package PGUI;
print __PACKAGE__;

my $PROGNAME = 'Stager';

use Prima qw(Application Buttons MsgBox FrameSet StdDlg Sliders Notebooks ScrollWidget ImageViewer);
use Prima::Image::jpeg; # although I can't see that it's helping.
$::wantUnicodeInput = 1;

use GK qw( VBox Table );

use FIO qw( config );
use Options;

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
			['~Preferences', sub { Options::mkOptBox($gui,getOpts()); }],
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
		size => [($w or 800),($h or 500)],
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
	$$gui{mainvbox}->destroy if $refresh;
	my @tabtexts;
	my @tabs = qw[ mem cba rol ];
	push(@tabs,'sho') if config('UI','showprodlist');
	push(@tabs,'ang') if config('UI','showsupportlist');
	foreach (@tabs) { # because tabs are controlled by option, tabnames must also be.
		if (/mem/) { push(@tabtexts,(config('Custom',$_) or "Members")); }
		elsif (/rol/) { push(@tabtexts,(config('Custom',$_) or "Roles")); }
		elsif (/sho/) { push(@tabtexts,(config('Custom',$_) or "Show")); }
		elsif (/ang/) { push(@tabtexts,(config('Custom',$_) or "Angels")); }
		elsif (/cba/) { push(@tabtexts,(config('Custom',$_) or "Faces")); }
	}
	$$gui{tablist} = \@tabs;
	my %args;
	if (defined config('UI','tabson')) { $args{orientation} = (config('UI','tabson') eq "bottom" ? tno::Bottom : tno::Top); } # set tab position based on config option
	$$gui{mainvbox} = getGUI("mainWin")->insert( VBox => name => "mainvbox", pack => { fill => "both", expand => 1, }, );
	$$gui{tabbar} = Prima::TabbedScrollNotebook->create(
		style => tns::Simple,
		tabs => \@tabtexts,
		name => 'Scroller',
		tabsetProfile => {colored => 0, %args, },
		pack => { fill => 'both', expand => 1, pady => 3, side => "left", },
	);
	$$gui{listpane} = $$gui{tabbar}->insert_to_page(0, VBox => name => "membox", pack => { fill => 'both' } );
	my $buttonbar = $$gui{mainvbox}->insert( HBox => name => 'buttons', pack => { side => "left", fill => 'x', expand => 0, }, );
	$$gui{tabbar}->owner($$gui{mainvbox});
	$$gui{listpane}->insert( Label => text => "Cast", height => 40, valignment => ta::Middle, pack => { fill => 'both', expand => 1, padx => 15, }, ) if (config('UI','splitmembers'));
	my $castbox = $$gui{listpane}->insert( HBox => name => "castall", pack => { fill => 'both', expand => 1, }, );
	my $actortarget = $castbox->insert( VBox => name => "castm", pack => { fill => 'both', expand => 1, }, );
	my $actresstarget = $castbox->insert( VBox => name => "castf", pack => { fill => 'both', expand => 1, }, );
	my $crewtarget;
	if (config('UI','splitmembers') or 0) {
		$$gui{listpane}->insert( Label => text => "Crew", height => 40, valignment => ta::Middle, pack => { fill => 'both', expand => 1, padx => 15, }, );
		$crewtarget = $$gui{listpane}->insert( HBox => name => "crewbox", pack => { fill => 'both', expand => 1, }, );
		$crewtarget->insert( VBox => name => 'thingone', pack => { fill => 'both', expand => 1, }, );
		$crewtarget->insert( VBox => name => 'thingtwo', pack => { fill => 'both', expand => 1, }, );
	}
	$buttonbar->insert( Button =>
		text => "Add a member",
		onClick => sub { addMember($gui,$dbh,$actortarget,$actresstarget,$crewtarget); },
		pack => { side => "right", fill => 'x', expand => 0, },
	);
	my $agebox = $buttonbar->insert( HBox => backColor => convertColor("#969"), pack => { fill => 'both', expand => 0, ipadx => 7, ipady => 7, padx => 7 }, );
	$agebox->insert( Label => text => '', name => 'spacer', pack => { fill => 'x', expand => 0, }, );
	my $agebut = $agebox->insert( Button =>
		text => "Cast by age",
		pack => { side => "right", fill => 'x', expand => 0, },
	);
	my $minage = $agebox->insert( SpinEdit => value => 0, min => 0, max => 100, step => 1, pageStep => 5 );
	my $maxage = $agebox->insert( SpinEdit => value => 99, min => 0, max => 100, step => 1, pageStep => 5 );
	my $genage = $agebox->insert( XButtons => name => 'gender', pack => { fill => "none", expand => 0, }, );
	$genage->arrange("left");
	$genage->build('',0,('M','M','F','F'));
	$agebut->onClick( sub { castByAge($gui,$dbh,$minage->value,$maxage->value,$genage->value); } );
# Pull records from DB
	my $res = FlexSQL::getMembers($dbh,'all',());
# foreach record:
	unless (defined $res) {
		Pdie("Error: Database access yielded undef!");
	} else {
		foreach (@$res) {
			putButtons($_,$actortarget,$actresstarget,$crewtarget,$gui,$dbh,0);
		}
	}
	$$gui{facelist} = $$gui{tabbar}->insert_to_page(1, VBox => name => "cast faces", pack => { fill => 'both', expand => 1, side => 'left', });
	$$gui{facelist}->insert( Label => text => "Select age range and gender above to fill this tab.", height => 60, pack => { fill => 'both', } );
	$$gui{rolepage} = $$gui{tabbar}->insert_to_page(2, VBox => name => "role details", pack => { fill => 'both', expand => 1, side => 'left', });
	my $memtext = (config("Custom",'mem') or "Members");
	$$gui{rolepage}->insert( Label => text => "Click on a member name on the $memtext page to fill this tab.", height => 60, pack => { fill => 'both', } );
	if (config('UI','showprodlist')) {
		$$gui{prodpage} = $$gui{tabbar}->insert_to_page(3, VBox => name => "show cast list", pack => { fill => 'both', expand => 1, side => 'left', });
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
	$$gui{tabbar}->pageIndex(2);
	my $res = FlexSQL::getMemberByID($dbh,$mid); #get info for given mid
	my %row = %$res;
	if (keys %row) {
		# list info
		my $age = 0;
		if (defined $row{dob}) {
			$age = Common::getAge($row{dob});
		}
		my $headshot = Prima::Image->new( size => [100,100] );
		if (defined $row{imgfn}) {
			$headshot->load("img/" . $row{imgfn}) or $headshot->load("img/noface.png") or sayBox($$gui{rolepage},"Could not load head shot: $@");
		} else {
			$headshot->load("img/noface.png") or sayBox($$gui{rolepage},"Could not load head shot placeholder: $@");
		}
		my $nametxt = "Name: $row{givname} $row{famname} ( $row{gender} age " . ($age ? $age : "unknown") . ")";
		my $meminfo = $$gui{rolepage}->insert( VBox => name => "memberinfo", pack => { fill => 'both', expand => 1 }, );
		my $header = labelBox($meminfo,$nametxt,"Roles",'h', boxfill => 'x', boxex => 1);
		$header->insert( Button => text => "Edit", onClick => sub { editMember($gui,$dbh,$res); } );
		$header->insert(ImageViewer => image => $headshot);
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
#print "Row: $row{rid} => $row{work} \n";
			showRole($dbh,$roletarget,$row{rid},$row{work},$row{troupe},$row{role},$row{year},$row{month},$row{mid},$row{rtype});
		}
		# place add role button
		my $addbutton = $meminfo->insert( Button => text => "Add a role", );
		$addbutton->onClick( sub { editRole($dbh, $mid, $roletarget, $addbutton); } );
	}
	$$gui{rolepage}->insert( Button => text => "Return", onClick =>  sub { $$gui{tabbar}->pageIndex(0); } );

	$loading->destroy();
}
print ".";

sub addMember {
	my ($gui,$dbh,$mtarget,$ftarget,$ctarget) = @_;
	editMemberDialog($gui,$dbh,(config('Custom','okadd') or "Add Member"),0,[$mtarget,$ftarget,$ctarget],());
}
print ".";

sub labelBox {
	my ($parent,$label,$name,$orientation,%args) = @_;
	my $box;
	unless (defined $orientation && $orientation =~ /[Hh]/) {
		$box = $parent->insert( VBox => name => "$name", alignment => ta::Left, );
		$box->pack( fill => ($args{boxfill} or 'none'), expand => ($args{boxex} or 1), padx => ($args{margin} or 1), pady => ($args{margin} or 1), );
	} else {
		$box = $parent->insert( HBox => name => "$name", alignment => ta::Left, );
		$box->pack( fill => ($args{boxfill} or 'none'), expand => ($args{boxex} or 1), padx => ($args{margin} or 1), pady => ($args{margin} or 1), );
	}
	$box->insert( Label => text => "$label", valignment => ta::Middle, alignment => ta::Left, pack => { fill => ($args{labfill} or 'x'), expand => ($args{labex} or 0), }  );
	return $box;
}
print ".";

sub editRole {
	my ($dbh, $mid, $target,$button,$existing,$killbutton) = @_;
	$button->hide();
#show => $sname, troupe => $tname, role => $role, year => $y, mon => $m, rtype => $rtype,
	my $editbox = $target->insert( HBox => name => 'roleadd', pack => { fill => 'x', expand => 0, }, );
	my $showbox = labelBox($editbox,"Production",'shobox','v',boxfill => 'x', boxex => 0, labex => 1);
	my $shows = FlexSQL::getShowList($dbh);
	my @showlist = values $shows;
	my $work = $showbox->insert( ComboBox => style => cs::DropDown, items => \@showlist, text => ($$existing{show} or ''), height => 30 );
	my $rolebox = labelBox($editbox,"Role",'rolbox','v',boxfill => 'x', labex => 1);
	my $role = $rolebox->insert( InputLine => text => ($$existing{role} or ''), pack => { fill => 'x' } );
	my $ybox = labelBox($editbox,"Year",'ybox','v',labex => 1);
	my $year = $ybox->insert( InputLine => text => ($$existing{year} or ''), width => 60, maxLen => 4 );
	my $mbox = labelBox($editbox,"Month",'mbox','v',labex => 1);
	my $month = $mbox->insert( InputLine => text => ($$existing{mon} or ''), width => 30, maxLen => 2 );
	my $tbox = labelBox($editbox,"Troupe",'tbox','v', boxfill => 'x', labex => 1);
	my $troupes = FlexSQL::getTroupeList($dbh);
	my @troupelist = values $troupes;
	my $troupe = $tbox->insert( ComboBox => style => cs::DropDown, items => \@troupelist, text => ($$existing{troupe} or config('InDef','troupe') or $troupelist[0] or ''), height => 30 );
	my $crewbox = labelBox($editbox,"Crew",'cbox','v');
	my $cbcrew = $crewbox->insert( SpeedButton => checkable => 1, checked => (($$existing{rtype} or 1) & 2 ? 1 : 0), );
	$cbcrew->onClick( sub { $cbcrew->text($cbcrew->checked ? "Y" : ""); } );
	my $submitter = $editbox->insert( Button => text => "Submit");
	$submitter->onClick( sub {
		if ($work->text eq '' or $troupe->text eq '' or $role->text eq '') { sayBox($editbox,"A required field is blank!"); return; }
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
			storeRole($dbh,$mid,$sid,$tid,$year->text,$month->text,$role->text,$cbcrew->checked,$target,($$existing{rid} or 0));
		} else {
			sayBox($editbox,"Something went wrong storing the role.");
		}
		($killbutton ? $button->destroy() : $button->show());
		$editbox->destroy();
		$submitter->destroy();
	} );
}
print ".";

sub showRole {
	my ($dbh,$target,$rid,$sid,$tid,$role,$y,$m,$mid,$rtype) = @_;
	my $tname = FlexSQL::getTroupeByID($dbh,$tid);
	my $sname = FlexSQL::getShowByID($dbh,$sid);
	my $row = labelBox($target,"$sname: $role ($tname, $m/$y)",'rolerow','h', boxfill => 'x', labfill => 'none');
	$row->backColor(convertColor(config('UI','rolebg') or "#99f"));
	my $editbut = $row->insert( Button => text => "Edit role", onClick => sub { editRole($dbh, $mid, $target,$row,{ show => $sname, troupe => $tname, role => $role, year => $y, mon => $m, rtype => $rtype, rid => $rid, },1) } );
	return 0;
}
print ".";

sub storeRole {
	my ($dbh,$mid,$sid,$tid,$y,$m,$role,$crew,$target,$rid) = @_;
	my %data = ( mid => $mid, work => $sid, troupe => $tid,
		year => $y, month => $m,
		role => $role, rtype => ($crew ? 2 : 1), );
	$data{rid} = $rid if ($rid > 0);
	my ($error,$st,@parms) = FlexSQL::prepareFromHash(\%data,'cv',$rid);
	if ($error) { sayBox(getGui('mainWin'),"Preparing role add/edit statement failed: $error - $parms[0]"); return; }
#print "Statement: $st (" . join(',',@parms) . ")\n";
	my $res = FlexSQL::doQuery(2,$dbh,$st,@parms);
	if ($DBI::err) {
		sayBox($target,"An error occurred: $DBI::errstr");
	}
	unless ($rid) {
		@parms = ($data{mid},$data{work},$data{troupe},$data{year},$data{month},$data{role});
		$st = "SELECT rid FROM cv WHERE mid=? AND work=? AND troupe=? AND year=? AND month=? AND role=?;";
		$res = FlexSQL::doQuery(0,$dbh,$st,@parms);
		unless ($DBI::err) {
			showRole($dbh,$target,$res,$sid,$tid,$role,$y,$m,$mid,$data{rtype});
		} else {
			sayBox($target,"An error occurred: $DBI::errstr");
		}
	} else {
		showRole($dbh,$target,$rid,$sid,$tid,$role,$y,$m,$mid,$data{rtype});
	}
}
print ".";

sub aboutBox {
	my $w = getGUI('mainWin');
	sayBox($w,"Stager is a membership tracking program intended for community theatre troupes. If there's anything you'd like to see added to the program, let the developer know.");
}
print ".";

sub devHelp {
	my ($target,$task) = @_;
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
		'004' => ['c',"Errors are fatal",'fatalerr'],
		'002' => ['n',"Age of Majority",'guarage',18,10,35,1],

		'005' => ['l',"Import/Export",'ImEx'],

		'010' => ['l',"Database",'DB'],
		'011' => ['r',"Database type:",'type',0,'M','MySQL','L','SQLite'],
		'012' => ['t',"Server address:",'host'],
		'013' => ['t',"Login name (if required):",'user'],
		'014' => ['c',"Server requires password",'password'],
##		'019' => ['r',"Conservation priority:",'conserve',0,'mem',"Memory",'net',"Network traffic (requires synchronization)"],

		'030' => ['l',"User Interface",'UI'],
		'032' => ['c',"Show production tab",'showprodlist'],
		'031' => ['s',"Notebook tab position: ",'tabson',1,"left","top","right","bottom"],
		'033' => ['c',"Show member contact in role listing",'showcontact'],
		'043' => ['x',"Background for role list",'rolebg',"#99F"],
		'034' => ['c',"Show members in different places (cast/crew/angels)",'splitmembers'],
##		'042' => ['x',"Foreground color: ",'fgcol',"#00000"],
##		'043' => ['x',"Background color: ",'bgcol',"#CCCCCC"],
		'035' => ['c',"Names on buttons as 'first last', not 'last, first'",'commalessname'],

		'050' => ['l',"Fonts",'Font'],
		'054' => ['f',"Tab font/size: ",'label'],
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
		'075' => ['t',"Edit member save button",'okedit'],
		'077' => ['t',"Add member save button",'okadd'],
		'078' => ['t',"User details dialog title",'udetail'],
		'079' => ['t',"Guardian dialog title",'guarinf'],

		'ff0' => ['l',"Debug Options",'Debug'],
		'ff1' => ['c',"Colored terminal output",'termcolors']
	);
	return %opts;
}
print ".";

sub refreshUI {
	my ($gui,$dbh) = @_;
	$gui = getGUI() unless (defined $$gui{status});
	$dbh = FlexSQL::getDB() unless (defined $dbh);
	print "Refreshing UI...\n";
	populateMainWin($dbh,$gui,1);
}
print ".";

sub editMember {
	my ($gui,$dbh,$user) = @_;
	editMemberDialog($gui,$dbh,(config('Custom','okedit') or "Save"),1,undef,%$user);
}
print ".";

sub editMemberDialog {
	my ($gui,$dbh,$buttontext,$isupdate,$targets,%user) = @_;
	my %user2;
	my %guardian;
	my $updateguar = 0;
	my $addbox = Prima::Dialog->create(
		borderStyle => bs::Sizeable,
		size => [400,480],
		text => (config('Custom','udetail') or "User Details"),
		owner => $$gui{mainWin},
		onTop => 1,
	);
	$addbox->hide();
	$::application->yield();
	my $vbox = $addbox->insert( VBox => name => 'details', pack => { fill => 'both', expand => 1 } );
	$vbox->insert( Button =>
		text => "Cancel",
		onClick => sub { print "Cancelled"; $addbox->destroy(); return undef; },
	);
	my $namebox = $vbox->insert( HBox => name => 'namebox', pack => { expand => 1, }, );
	my $nbox1 = labelBox($namebox,"Given Name",'n1','v');
	my $nbox2 = labelBox($namebox,"Family Name",'n2','v');
	my $givname = $nbox1->insert( InputLine => maxLen => 23, text => ($user{givname} or ''), );
	my $famname = $nbox2->insert( InputLine => maxLen => 28, text => ($user{famname} or ''), );
	my $phonbox = $vbox->insert( HBox => name => 'phones', pack => { fill => 'x', expand => 1, }, );
	my $hpbox = labelBox($phonbox,"Home Phone",'pb1','v');
	my $hphone = $hpbox->insert( InputLine => maxLen => 10, width => 150, text => ($user{hphone} or '##########'), );
	my $mpbox = labelBox($phonbox,"Mobile/Work Phone",'pb2','v');
	my $mphone = $mpbox->insert( InputLine => maxLen => 10, width => 150, text => ($user{mphone} or '##########'), );
	$vbox->insert( Label => text => "E-mail Address" );
	my $email = $vbox->insert( InputLine => maxLen => 254, text => ($user{email} or config('InDef','email') or 'user@example.com'), pack => { fill => 'x', } );
	my $abox = labelBox($vbox,"Birthdate (YYYYMMDD)",'abox','h',boxfill => 'x');
# TODO: Add calendar button for date of birth? (if option selected?)
	my $dob = $abox->insert( InputLine => maxLen => 10, width => 120, text => ($user{dob} or ''), );
	my $guarneed = ((Common::getAge($dob->text) or 0) < (config('Main','guarage') or "18"));
	my $guarbuttext = ($guarneed ? "Guardian" : "Adult");
	if ($isupdate) { # Pull guardian information from DB if this is an update
		my $cmd = "SELECT * FROM guardian WHERE mid=?;";
		my $res = (FlexSQL::doQuery(6,$dbh,$cmd,$user{mid}) or {}); # silent failure, and failure is graceful
		%guardian = %$res;
		$updateguar = (keys %guardian ? 1 : 0);
	}
	my $guartext = ($guarneed ? "Guardian: " . ($guardian{name} or 'unknown') . " " . ($guardian{phone} or '') : "---");
	my $guarlabel;
	my $guar = $abox->insert( Button => text => $guarbuttext, enabled => $guarneed, onClick => sub { %guardian = guardianDialog($$gui{mainWin}); $guarlabel->text("Guardian: " . ($guardian{name} or 'unknown') . " " . ($guardian{phone} or '')); $updateguar |= 2; }, );
	$dob->onChange( sub {
		return if (length($dob->text) < 8); # no point checking an incomplete date
		$guarneed = ((Common::getAge($dob->text) or 0) < (config('Main','guarage') or "18"));
		$guar->text($guarneed ? "Guardian" : "Adult");
		$guar->enabled($guarneed);
	}, );
	$guarlabel = $vbox->insert( Label => text => $guartext, );
	my $gbox = labelBox($vbox,"Gender",'gbox','h',boxfill => 'x');
	my $gender = $gbox-> insert( XButtons => name => 'gen', pack => { fill => "none", expand => 0, }, );
	$gender->arrange("left"); # line up buttons horizontally (TODO: make this an option in the options hash? or depend on text length?)
	my @presets = ("M","M","F","F");
	my $current = ($user{gender} or "M"); # pull current value from config
	$current = Common::findIn($current,@presets); # by finding it in the array
	$current = ($current == -1 ? scalar @presets : $current/2); # and dividing its position by 2 (behavior is undefined if position is odd)
	$gender-> build("",$current,@presets); # turn key:value pairs into exclusive buttons
	$vbox->insert( Label => text => "Street Address" );
	my $address = $vbox->insert( InputLine => maxLen => 253, text => ($user{address} or ''), pack => { fill => 'x', } );
	my $cbox = $vbox->insert( HBox => name => 'citybox', pack => { expand => 1, }, );
	my $cbox1 = labelBox($cbox,"City",'c1','v',boxfill => 'x', labfill => 'x');
	my $cbox2 = labelBox($cbox,"State",'c2','v');
	my $cbox3 = labelBox($cbox,"ZIP",'c3','v');
	my $city = $cbox1->insert( InputLine => maxLen => 99, text => ($user{city} or config('InDef','city') or ''), pack => { fill => 'x', expand => 1} );
	my $state = $cbox2->insert( InputLine => maxLen => 3, text => ($user{state} or config('InDef','state') or ''), width => 45, );
	my $zip = $cbox3->insert( InputLine => maxLen => 10, text => ($user{zip} or config('InDef','ZIP') or ''), );
	my $mtbox = labelBox($vbox,"Type:",'rb','h');
	my $memtype = ($user{memtype} or 0);
	my $cbcast = $mtbox->insert( CheckBox => text => "Cast", checked => ($memtype & 1) );
	my $cbcrew = $mtbox->insert( CheckBox => text => "Crew", checked => ($memtype & 2) );
	my $imbox = labelBox($vbox,"Headshot filename",'im','h', boxex => 1, boxfill => 'x');
	my $img = $imbox->insert( InputLine => maxLen => 256, text => ($user{imgfn} or 'noface.png'), pack => { fill => 'x', expand => 1, }, );
	$vbox->insert( Button =>
		text => $buttontext,
		onClick => sub {
			$addbox->hide();
			# process information
			unless ($famname->text ne '' && $givname->text ne '') {
				sayBox($addbox,"Required fields: Family Name, Given Name");
				$addbox->show();
				return;
			}
			$user2{famname} = $famname->text;
			$user2{givname} = $givname->text;
			$user2{hphone} = $hphone->text if ($hphone->text ne '##########');
			$user2{mphone} = $mphone->text if ($mphone->text ne '##########');
			$user2{email} = $email->text if ($email->text ne (config('InDef','email') or 'user@example.com'));
			$user2{dob} = $dob->text if ($dob->text ne '');
			$user2{gender} = $gender->value;
			$user2{address} = $address->text if ($address->text ne '');
			$user2{city} = $city->text if ($city->text ne '' && $address->text ne '');
			$user2{state} = $state->text if ($state->text ne '' && $address->text ne '');
			$user2{zip} = $zip->text if ($zip->text ne '' && $address->text ne '');
#			# This is used for (config('UI','splitmembers').
			$user2{memtype} = 0;
			$user2{memtype} += 1 if $cbcast->checked;
			$user2{memtype} += 2 if $cbcrew->checked;
			$user2{imgfn} = $img->text if ($img->text ne 'noface.png');
			$addbox->destroy();
			unless ($isupdate) {
				my ($error,$cmd,@parms) = FlexSQL::prepareFromHash(\%user2,'member',0);
				if ($error) { sayBox($$gui{mainWin},"Preparing user add statement failed: $error - $parms[0]"); return; }
				$error = FlexSQL::doQuery(2,$dbh,$cmd,@parms);
				unless ($error == 1) { sayBox($$gui{mainWin},"Adding user to database failed: $error"); return; }
				$cmd = "SELECT givname, famname, mid, gender, memtype FROM member WHERE famname=? AND givname=?;";
				@parms = ($user2{famname},$user2{givname});
				my $res = FlexSQL::doQuery(4,$dbh,$cmd,@parms);
				unless (defined $res) {
					Pdie("Error: Database access yielded undef!");
				} else {
					foreach (@$res) {
						if ($guarneed and defined keys %guardian) { # insert guardian record, if applicable
							$guardian{mid} = $$_[2]; # member ID from result
							storeGuardian($gui,$dbh,0,\%guardian);
						}
						putButtons($_,@$targets,$gui,$dbh);
					}
				}
			} else {
				foreach (keys %user2) {
					delete $user2{$_} if ($user2{$_} eq $user{$_}); # remove unchanged/identical values from update queue.
				}
				return unless (defined $user{mid}); #Have to know whom we're updating.
				unless (scalar keys %user2) {
					unless ($updateguar & 2) {
						sayBox($$gui{mainWin},"Error: No changes made. If cancelling, click cancel.");
					} else {
						$guardian{mid} = $user{mid};
						my $error = storeGuardian($gui,$dbh,($updateguar & 1),\%guardian);
						sayBox($$gui{mainWin},"Guardian updated.") unless $error;
					}
					return;
				} # no changes? return.
				$user2{mid} = $user{mid}; # put ID key in hash we'll be using for prepare
				if ($guarneed and defined keys %guardian) { # insert/update guardian record, if applicable
					$guardian{mid} = $user{mid};
					storeGuardian($gui,$dbh,($updateguar & 1),\%guardian);
				}
				my ($error,$cmd,@parms) = FlexSQL::prepareFromHash(\%user2,'member',1); # prepare update stateent
				if ($error) { sayBox($$gui{mainWin},"Preparing user update statement failed: $error - $parms[0]"); return; }
				$error = FlexSQL::doQuery(2,$dbh,$cmd,@parms); # run update statement on database, get back number of rows updated (should be 1)
				unless ($error == 1) { sayBox($$gui{mainWin},"Updating user information failed: $error"); return; }
				showRoleEditor($gui,$dbh,$user2{mid});# reshow role editor (only makes visible changes to name, age, and possibly contact info
			} # end else (updating info)
		} # end OK button subroutine
	); # End of button bar under details
	$addbox->show(); # reveal our handiwork!!
}
print ".";

sub guardianDialog {
	my $parent = shift;
	return askbox($parent,(config('Custom','guarinf') or "Guardian Info"),name=>"Guardian Name",phone=>"Guardian Phone #");
}
print ".";

sub askbox { # makes a dialog asking for the answer(s) to a given list of questions, either a single scalar, or an array of key/question pairs whose answers will be stored in a hash with the given keys.
	my ($parent,$tibar,@questions) = @_; # using an array allows single scalar question and preserved order of questions asked.
	my $numq = int((scalar @questions / 2)+ 0.5);
	print "Asking $numq questions...\n";
	my $height = ($numq * 25) + 75;
	my $askbox = Prima::Dialog->create(
		centered => 1,
		borderStyle => bs::Sizeable,
		onTop => 1,
		width => 400,
		height => $height,
		owner => $parent,
		text => $tibar,
		valignment => ta::Middle,
		alignment => ta::Left,
	);
	my $extras = {};
	my $buttons = mb::OkCancel;
	my %answers;
	my $vbox = $askbox->insert( VBox => autowidth => 1, pack => { fill => 'both', expand => 0, }, );
	if (scalar @questions % 2) { # not a valid hash; assuming a single question
		$numq = 0;
		@questions = (one => $questions[0]); # discard all but the first element. Add a key for use by hash unpacker
	}
	my $i = 0;
	until ($i > $#questions) {
		my $row = labelBox($vbox,$questions[$i+1],"q$i",'h',boxfill=>'both', labfill => 'none', margin => 7, );
		my $ans = $row->insert(InputLine => text => '', );
		my $key = $questions[$i];
		$ans->onChange( sub { $answers{$key} = $ans->text; } );
		$i += 2;
	}
	my $spacer = $vbox->insert( Label => text => " ", pack => { fill => 'both', expand => 1 }, );
	my $fresh = Prima::MsgBox::insert_buttons( $askbox, $buttons, $extras); # not reinventing wheel
	$askbox->execute;
	if ($numq == 0) {
		return $answers{one};
	} else {
		return %answers;
	}
}
print ".";

sub storeGuardian {
	my ($gui,$dbh,$isupdate,$g) = @_;
	my ($error,$cmd,@parms) = FlexSQL::prepareFromHash($g,'guardian',$isupdate);
	if ($error) {
		sayBox($$gui{mainWin},"Preparing guardian " . ($isupdate ? "update" : "add") . " statement failed: $error - $parms[0]");
		return 1;
	} else {
		$error = FlexSQL::doQuery(2,$dbh,$cmd,@parms);
		unless ($error == 1) { sayBox($$gui{mainWin},($isupdate ? "Updating guardian information" : "Adding guardian to database") . " failed: $error"); return 2; }
	}
	return 0;
}
print ".";

sub putButtons {
	my ($ar,$mtar,$ftar,$ctar,$gui,$dbh,$imagebutton) = @_;
	my @a = @$ar;
	my $target = (($a[3] =~ m/[Mm]/) ? $mtar : $ftar);
	# TODO: use $a[2] (member ID) to count roles from roles table
	my $text = (($imagebutton or config('UI','commalessname')) ? "$a[0] $a[1]" : "$a[1], $a[0]"); # concatenate famname, givname and put a label in the window.
	if (config('UI','splitmembers')) {
		if ($a[4] & 2) { #crew
			my ($thingone, $thingtwo); # complicated rigamarole to make it alternate between columns when placing crew buttons
			foreach ($ctar->get_widgets) {
				$thingone = $_ if ($_->name eq 'thingone');
				$thingtwo = $_ if ($_->name eq 'thingtwo');
			}
			$thingone = $ctar unless defined $thingone;
			$thingtwo = $ctar unless defined $thingtwo;
			my @b = $thingone->get_widgets;
			my $c = scalar @b;
			@b = $thingtwo->get_widgets;
			my $d = scalar @b;
			print "Count: $c/$d\n";
			my $crewtarget = ($c > $d ? $thingtwo : $thingone);
			putButton($gui,$dbh,$a[2],$text,$crewtarget,$imagebutton,$a[5]);
		}
		unless ($a[4] & 1) { return; }; # not actor
	}
	putButton($gui,$dbh,$a[2],$text,$target,$imagebutton,$a[5]);
}
print ".";

sub putButton {
	my ($gui,$dbh,$id,$label,$target,$image,$src) = @_;
	if ($image) {
		my $headshot = Prima::Image->new( size => [100,100]);
		if (defined $src) {
			$headshot->load("img/$src") or $headshot->load("img/noface.png") or sayBox($$gui{rolepage},"Could not load head shot: $@");
		} else {
			$headshot->load("img/noface.png") or sayBox($$gui{rolepage},"Could not load head shot placeholder: $@");
		}		
		# TODO: Make image a bitwise value, declaring options: vertical, thumbnail resizing, etc.
		# if ($image & 2) { $headshot->size( [20,20] ); } # for example
		$target->insert( Button => text => $label,
			onClick => sub { showRoleEditor($gui,$dbh,$id); }, # link button to role editor
			image => $headshot,
			flat => 1,
			vertical => 1,
		);
	} else{
		$target->insert( Button =>
			text => $label,
			alignment => ta::Left,
			pack => { fill => 'x' },
			onClick => sub { showRoleEditor($gui,$dbh,$id); }# link button to role editor
		);
	}
}
print ".";

sub castByAge {
	my ($gui,$dbh,$n,$x,$g) = @_;
#	print "I received $n-$x ($g)\n";
	$g = ($g =~ m/[Mm]/ ? 'M' : 'F');
	# including all columns for compatibility with putButtons
	my $cmd = "SELECT givname,famname,mid,gender,memtype,imgfn FROM member WHERE memtype & 1 AND gender=? AND (dob IS NULL OR dob<? AND dob>?) ORDER BY dob;";
	my ($maxdob,$mindob) = Common::DoBrangefromAges($n,$x,1);
	my @parms = ($g,$maxdob,$mindob);
#	print "Parms: " . join(',',@parms) . "\n";
	my $res = FlexSQL::doQuery(4,$dbh,$cmd,@parms);
	unless (defined $res) {
		Pdie("Error: Database access yielded undef!");
	} else {
		my $vbox = $$gui{facelist};
		foreach ($vbox->get_widgets) {
			$_->destroy();
		}
		my $row;
		my $r = 0;
		my $column = 0;
		unless (@$res) {
			$vbox->insert( Label => text => "No results. Try a new range.", height => 60, pack => { fill => 'both', } );
		}
		foreach (@$res) {
			if ($column == 0) {
				$column++; $r++;
				$row = $vbox->insert( HBox => name => "row$r", pack => { fill => 'x', expand => 0, }, );
			}
			putButtons($_,$row,$row,$row,$gui,$dbh,1);
			$column++;
			if ($column > (config('UI','facecols') or 4)) {
				$column = 0; # reset column, triggering new row creation.
			}
		}
	}
	$$gui{tabbar}->pageIndex(1);
}
print ".";

print " OK; ";
1;
