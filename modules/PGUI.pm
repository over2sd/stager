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

=item Pdie()
Causes program to die by closing the main window.
If a MESSAGE is passed to the function, it will be displayed in a
message box before dying.
=cut
sub Pdie {
	my $message = shift;
	my $w = getGUI('mainWin');
	message_box("Fatal Error",$message,mb::Yes | mb::Error);
	$w->close();
	exit(-1);
}

sub Pwait {
	# Placeholder for if I ever figure out how to do a non-blocking sleep function in Prima
	my $duration = shift or 1;
	my $start = time();
	my $end = ($start+$duration);
	while ($end > time()) {
#		while (events_pending()) {
			$::application->yield();
#		}
		# 10ms sleep.
		# Not much, but prevents processor spin without making waiting dialogs unresponsive.
		select(undef,undef,undef,0.01);
	}
	return 0;
}

=item buildMenus
This function creates the menu structure for the dropdown menubar at
the top of the program. Pretty standard stuff.
Returns a reference to the array describing the menus.
=cut
sub buildMenus { #Replaces Gtk2::Menu, Gtk2::MenuBar, Gtk2::MenuItem
	my $gui = shift;
	my $menus = [
		[ '~File' => [
#			['~Export', sub { message('export!') }],
#			['~Synchronize', 'Ctrl-S', '^S', sub { message('synch!') }],
			['~Preferences', sub { Options::mkOptBox($gui,getOpts()); }],
			[],
			['Close', 'Ctrl-W', km::Ctrl | ord('W'), sub { my $err = savePos($$gui{mainWin}) if (config('Main','savepos')); Common::errorOut('PGUI::savePos',$err) if $err; $$gui{mainWin}->close() } ],
		]],
		[ '~Help' => [
			['~About', \&aboutBox],
		]],
	];
	return $menus;
}
print ".";

=item convertColor COLOR FORCE
Takes a COLOR as either an integer value recognized by Prima or a hex
string as #nnn or #nnnnnn.
If FORCE is 1, the program will send the value to the converter even if
it is only numerals (useful for sendiung 0x999  as '999' (without the #)
This is useful for calling from an input box, which we don't expect the
user to be putting valid Prima integers into.
Returns an INTEGER.
=cut
sub convertColor {
	my ($color,$force) = @_;
	return undef unless (defined $color); # undef if no color given
	return $color unless ($force or $color =~ m/^#/); # return color unchanged unless it starts with '#' (allows passing integer straight through, as saveConf is going to write it as int, but we want user to be able to write it as #ccf).
	return ColorRow::stringToColor($color); # convert e.g. "#ccf" to integer needed by Prima
}
print ".";

=item createMainWin VERSION WIDTH HEIGHT
Makes the main window and passes back a hashref to the window set
(allowing easy access to the main window, the statusbar, etc.). The
specified VERSION (required) goes in the titlebar. If a WIDTH and
HEIGHT are specified, the window is resized to these values. However,
if the configuration option to save window position is enabled, these
values will be overridden by the stored size.
Returns a HASREF.
=cut
my %windowset;
sub createMainWin {
	my ($version,$w,$h) = @_;
	my $window = Prima::MainWindow->new(
		text => (config('Custom','program') or "$PROGNAME") . " v.$version",
		size => [($w or 800),($h or 500)],
		onClose => sub { FlexSQL::closeDB(); },
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

=item createSplash PARENT
Makes a splash panel in PARENT for displaying load progress of database.
On a fast machine, with database access information already configured,
this may not even be noticeable before it is replaced with the actual
GUI.
Returns an OBJECT REFERENCE for the progress bar and an OBJECT
REFERENCE for the splash box.
=cut
sub createSplash {
	my $window = shift;
	my $vb = $window->insert( VBox => name => "splashbox", pack => { anchor => "n", fill => 'x', expand => 0, relx => 0.5, rely => 0.5, padx => 5, pady => 5, }, );
	my $label = $vb->insert( Label => text => "Loading " . (config('Custom','program') or "$PROGNAME") . "...", pack => { fill=> "x", expand => 0, side => "left", relx => 0.5, padx => 5, pady => 5,},);
	my $progress = $vb->insert( Gauge =>
		value => 0,	
		relief => gr::Raise,
		height => 35,
		pack => { fill => 'x', expand => 0, padx => 3, side => "left", },
	);
	return $progress,$vb;
}
print ".";

=item GetGUI KEY
Gets (or creates if not present) the GUI, or returns a distinct part of
the GUI, such as the stausbar or the main window.
Returns a HASHREF, an OBJECT REFERENCE if a valid KEY was supplied, or
UNDEF if an invalid KEY was supplied.
=cut
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

=item getStatus PARENT
Places a statusbar in PARENT window, or returns the existing statusbar.
Returns an OBJECT REFERENCE to the statustbar.
=cut
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

=item getTabByCode CODE
Attempts to find the tab page labeled CODE and return its page ID.
Returns an INTEGER, or UNDEF.
=cut
sub getTabByCode { # for definitively finding page ID of tabs...
	my $code = shift;
	my $tabs = (getGUI("tablist") or []);
	return Common::findIn($code,@$tabs);
}
print ".";

=item loadDBwithSplashDetail GUI
Loads the database, asking for required information, if it is not
configured.
On a fast machine, with database access information already configured,
this may not even be noticeable before it is replaced with the actual
GUI.
Returns a DATABASE HANDLE.
=cut
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
						font => applyFont('button'),
					},
					mb::No, {
						text => "SQLite", hint => "Use if you can't use MySQL.",
						font => applyFont('button'),
					},
					mb::Cancel, {
						text => "Quit", hint => "Abort loading the program (until you set up your database?)",
						font => applyFont('button'),
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
		# ask user if username required
			my $umand = (message("Username required?",mb::YesNo) == mb::Yes ? 'y' : 'n');
		# ask user if password required
			my $pmand = (message("Password required?",mb::YesNo) == mb::Yes ? 'y' : 'n');
		# ask user for host
			my $host = input_box("Server Info","Server address:","127.0.0.1");
		# ask user for SQL username, if needed by server (might not be, for localhost)
			my $uname = ($umand eq 'y' ? input_box("Login Credentials","Username (if required)","") : undef);
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
	my ($dbh,$error,$errstr) = FlexSQL::getDB($base,$host,'stager',$passwd,$uname);
	unless (defined $dbh) { # error handling
		Common::errorOut('FlexSQL::getDB',$error,string => $errstr);
		Pdie("ERROR: $errstr");
		print "Exiting (no DB).\n";
	} else {
		$curstep->text("---");
		Common::errorOut('FlexSQL::getDB',0);
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

=item populateMainWin HANDLE GUI REFRESH
Fills or refreshes the main program window, depending on the value of
REFRESH.
No return value.
=cut
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
		tabsetProfile => {colored => 0, %args, font => applyFont('label'), },
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
		$$gui{listpane}->insert( Label => text => "Crew", height => 40, valignment => ta::Middle, pack => { fill => 'both', expand => 1, padx => 15, }, font => applyFont('body'), );
		$crewtarget = $$gui{listpane}->insert( HBox => name => "crewbox", pack => { fill => 'both', expand => 1, }, );
		$crewtarget->insert( VBox => name => 'thingone', pack => { fill => 'both', expand => 1, }, );
		$crewtarget->insert( VBox => name => 'thingtwo', pack => { fill => 'both', expand => 1, }, );
	}
	$buttonbar->insert( Button =>
		text => "Add a member",
		onClick => sub { addMember($gui,$dbh,$actortarget,$actresstarget,$crewtarget); },
		pack => { side => "right", fill => 'x', expand => 0, },
		hint => "Click to add a new member to the database.",
		font => applyFont('button'),
	);
	my $agebox = $buttonbar->insert( HBox => backColor => convertColor("#969"), pack => { fill => 'both', expand => 0, ipadx => 7, ipady => 7, padx => 7 }, );
	$agebox->insert( Label => text => '', name => 'spacer', pack => { fill => 'x', expand => 0, }, );
	my $agebut = $agebox->insert( Button =>
		text => "Cast by age",
		pack => { side => "right", fill => 'x', expand => 0, },
		font => applyFont('button'),
		hint => "Click to see a list of cast between the ages given at the right.",
	);
	my $minage = $agebox->insert( SpinEdit => value => 0, min => 0, max => 100, step => 1, pageStep => 5, hint => "Enter the youngest actor you would cast.", );
	my $maxage = $agebox->insert( SpinEdit => value => 99, min => 0, max => 100, step => 1, pageStep => 5, hint => "Enter the oldest actor you would cast.", );
	my $genage = $agebox->insert( XButtons => name => 'gender', pack => { fill => "none", expand => 0, }, hint => "Click the gender of the character to be cast.", font => applyFont('button'),);
	$genage->arrange("left");
	$genage->build('',1,('M','M','F','F'));
	$agebut->onClick( sub { castByAge($gui,$dbh,$minage->value,$maxage->value,$genage->value); } );
	$genage->onChange( sub { castByAge($gui,$dbh,$minage->value,$maxage->value,$genage->value); } );
# Pull records from DB
	my $res = FlexSQL::getMembers($dbh,'all',());
# foreach record:
	unless (defined $res) {
		Pdie("Error: Database access yielded undef!");
	} else {
		foreach (@$res) {
			my $image = 0;
			if (config('UI','headthumb')) { $image += 2; }
			putButtons($_,$actortarget,$actresstarget,$crewtarget,$gui,$dbh,$image);
		}
	}
	$$gui{facelist} = $$gui{tabbar}->insert_to_page(1, VBox => name => "cast faces", pack => { fill => 'both', expand => 1, side => 'left', font => applyFont('body'), });
	$$gui{facelist}->insert( Label => text => "Select age range and gender above to fill this tab.", height => 60, pack => { fill => 'both', } );
	$$gui{rolepage} = $$gui{tabbar}->insert_to_page(2, VBox => name => "role details", pack => { fill => 'both', expand => 1, side => 'left', font => applyFont('body'), });
	my $memtext = (config("Custom",'mem') or "Members");
	$$gui{rolepage}->insert( Label => text => "Click on a member name on the $memtext page to fill this tab.", height => 60, pack => { fill => 'both', } );
	if (config('UI','showprodlist')) {
		$$gui{prodpage} = $$gui{tabbar}->insert_to_page(3, VBox => name => "show cast list", pack => { fill => 'both', expand => 1, side => 'left', font => applyFont('body'), });
		my $selshowrow = labelBox($$gui{prodpage},"Select show and troupe:",'selbox','h', boxfill => 'x', boxex => 0,);
		my $shows = FlexSQL::getShowList($dbh);
		my @showlist = values $shows;
		my $work = $selshowrow->insert( ComboBox => style => cs::DropDown, items => \@showlist, text => '', height => 30 );
		my $troupes = FlexSQL::getTroupeList($dbh);
		my @troupelist = values $troupes;
		my $troupe = $selshowrow->insert( ComboBox => style => cs::DropDown, items => \@troupelist, text => (config('InDef','troupe') or ''), height => 30 );
		my $castlist = $$gui{prodpage}-> insert( VBox => name => 'castbox', pack => { fill => 'both', expand => 0, });
		$selshowrow->insert( Button => text => "Show Cast/Crew", onClick => sub { my $sid = Common::revGet($work->text,undef,%$shows); my $tid = Common::revGet($troupe->text,undef,%$troupes); castShow($dbh,$castlist,$sid,$tid); }, font => applyFont('button'), );
	}
	$$gui{status}->push("Ready.");
	print " Done.";
}
print ".";

=item sayBox PARENT TEXT
Makes a dialog box with a message of TEXT and an owner of PARENT.
GUI equivalent to 'print TEXT;'.
No return value.
=cut
sub sayBox {
	my ($parent,$text) = @_;
	message($text,owner=>$parent);
}
print ".";

=item showRoleEditor GUI HANDLE ID
Puts a list of member #ID's roles in the rolepage object of GUI, pulling
information using the given database HANDLE.
No return value.
=cut
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
		$header->insert( Button => text => "Edit", onClick => sub { editMember($gui,$dbh,$res); }, font => applyFont('button'), hint => "Click to edit member information.", );
		$header->insert(ImageViewer => image => $headshot);
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
		my $addbutton = $meminfo->insert( Button => text => "Add a role", font => applyFont('button'), hint => "Click to add a role to this member.", );
		$addbutton->onClick( sub { editRole($dbh, $mid, $roletarget, $addbutton); } );
	}
	$$gui{rolepage}->insert( Button => text => "Return", onClick =>  sub { $$gui{tabbar}->pageIndex(0); }, font => applyFont('button'), hint => "Click to return to the Members tab.", );

	$loading->destroy();
}
print ".";

=item addMember
Displays a dialog for adding a member.
No return value.
=cut
sub addMember {
	my ($gui,$dbh,$mtarget,$ftarget,$ctarget) = @_;
	editMemberDialog($gui,$dbh,(config('Custom','okadd') or "Add Member"),0,[$mtarget,$ftarget,$ctarget],());
}
print ".";

=item labelBox CONTAINER TEXT NAME ORIENTATION HASH
This function builds a vertical or horizontal box (depending on the
value of ORIENTATION; defaults to 'V' if missing or malformed) named
NAME and containing a label that says TEXT inside CONTAINER.

These additional arguments may be passed in the optional HASH:
* boxfill - How will the new box fill its parent? (pack=>fill values)
* boxex - Will the new box expand (pack=>expand values)
* margin - Padding around the new box
* labfill - How will the label fill the new box? (pack=>fill values)
* labex - Will the label expand (pack=>expand values)

Returns a VBox or HBox named NAME.
=cut
sub labelBox {
	my ($parent,$label,$name,$orientation,%args) = @_;
	die "[E] Missing parameter to labelBox" unless (defined $parent and defined $label and defined $name);
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

=item editRole HANDLE MEMBER CONTAINER BUTTON ROLE DISPOSABLE
Displays a row in CONTAINER allowing the user to edit the role
information of member #MEMBER using database handle HANDLE to retrieve
and update information. BUTTON is hidden during this process.

If this is an existing role being edited, BUTTON might actually be an
HBox created by a previous call to editRole(), in which case the user
passes information about the role in a hashref ROLE and may indicate
that BUTTON is DISPOSABLE, so editRole() will destroy it after editing.

Once the user presses the Submit button, editRole() will attempt to
store the new information using a call to storeRole(), which will also
place a row with the updated information in the CONTAINER.
No return value.
=cut
sub editRole {
	my ($dbh, $mid, $target,$button,$existing,$killbutton) = @_;
	$button->hide();
#show => $sname, troupe => $tname, role => $role, year => $y, mon => $m, rtype => $rtype,
	my $editbox = $target->insert( HBox => name => 'roleadd', pack => { fill => 'x', expand => 0, }, );
	my $showbox = labelBox($editbox,"Production",'shobox','v',boxfill => 'x', boxex => 0, labex => 1);
	my $shows = FlexSQL::getShowList($dbh);
	my @showlist = values $shows;
	my $work = $showbox->insert( ComboBox => style => cs::DropDown, items => \@showlist, text => ($$existing{show} or ''), height => 30, hint => "The name of the production", );
	my $rolebox = labelBox($editbox,"Role",'rolbox','v',boxfill => 'x', labex => 1);
	my $role = $rolebox->insert( InputLine => text => ($$existing{role} or ''), pack => { fill => 'x' }, hint => "The role played (or job filled) in the production", );
	my $ybox = labelBox($editbox,"Year",'ybox','v',labex => 1);
	my $year = $ybox->insert( InputLine => text => ($$existing{year} or ''), width => 60, maxLen => 4, hint => "The year of the production", );
	my $mbox = labelBox($editbox,"Month",'mbox','v',labex => 1);
	my $month = $mbox->insert( InputLine => text => ($$existing{mon} or ''), width => 30, maxLen => 2, hint => "The month of the production", );
	my $tbox = labelBox($editbox,"Troupe",'tbox','v', boxfill => 'x', labex => 1);
	my $troupes = FlexSQL::getTroupeList($dbh);
	my @troupelist = values $troupes;
	my $troupe = $tbox->insert( ComboBox => style => cs::DropDown, items => \@troupelist, text => ($$existing{troupe} or config('InDef','troupe') or $troupelist[0] or ''), height => 30, hint => "The theater group that performed the production", );
	my $crewbox = labelBox($editbox,"Crew",'cbox','v');
	my $cbcrew = $crewbox->insert( SpeedButton => checkable => 1, checked => (($$existing{rtype} or 1) & 2 ? 1 : 0), font => applyFont('button'), hint => "Check this if it was a crew role.", );
	$cbcrew->onClick( sub { $cbcrew->text($cbcrew->checked ? "Y" : ""); } );
	my $submitter = $editbox->insert( Button => text => "Submit", font => applyFont('button'), hint => "Click to submit this information.", );
	$submitter->onClick( sub {
		if ($work->text eq '' or $troupe->text eq '' or $role->text eq '') { sayBox($editbox,"A required field is blank!"); return; }
		my $sid = Common::revGet($work->text,undef,%$shows);
		my $tid = Common::revGet($troupe->text,undef,%$troupes);
		unless (defined $sid) {
			Common::errorOut('Inline',0,string => "[I] New show: " . $work->text . " will be added to database.");
			my $st = "INSERT INTO work (sname) VALUES(?);";
			my $res = FlexSQL::doQuery(2,$dbh,$st,$work->text);
			$st = "SELECT wid FROM work WHERE sname=?;";
			$res = FlexSQL::doQuery(0,$dbh,$st,$work->text);
			$sid = $res unless ($DBI::err);
		}
		unless (defined $tid) {
			Common::errorOut('Inline',0,string => "[I] New troupe: " . $troupe->text . " will be added to database.");
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


=item showRole HANDLE CONTAINER (list of role field values)
Builds a row displaying information about the role described in the
list of values within CONTAINER. Database HANDLE is passed through to a
function called by the button at the end of this row.
Returns a filled HBox.
=cut
sub showRole {
	my ($dbh,$target,$rid,$sid,$tid,$role,$y,$m,$mid,$rtype) = @_;
	my $tname = FlexSQL::getTroupeByID($dbh,$tid);
	my $sname = FlexSQL::getShowByID($dbh,$sid);
	unless (defined $sname and $sname ne '') { return 1; }
	my $row = labelBox($target,"$sname: $role ($tname, $m/$y)",'rolerow','h', boxfill => 'x', labfill => 'none');
	$row->backColor(convertColor(config('UI','rolebg') or "#99f"));
	my $editbut = $row->insert( Button => text => "Edit role", onClick => sub { editRole($dbh, $mid, $target,$row,{ show => $sname, troupe => $tname, role => $role, year => $y, mon => $m, rtype => $rtype, rid => $rid, },1) }, font => applyFont('button'), hint => "Click to edit the information about this role.", );
	return $row;
}
print ".";

=item storeRole
Given a database handle and a list of values in the proper order, this
function stores the values in the database and displays the role in a
supplied target.
No return value.
=cut
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
	unless ($rid) { # gets the role ID. If we had it already, we skip this and just display the role.
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

=item aboutBox
Displays the program's 'About' box.
No return value.
=cut
sub aboutBox {
	my $w = getGUI('mainWin');
	sayBox($w,"Stager is a membership tracking program intended for community theatre troupes. If there's anything you'd like to see added to the program, let the developer know.");
}
print ".";

=item devHelp PARENT UNFINISHEDTASK
Displays a message that UNFINISHEDTASK is not done but is planned.
TODO: Remove from release.
No return value.
=cut
sub devHelp {
	my ($target,$task) = @_;
	sayBox($target,"$task is on the developer's TODO list.\nIf you'd like to help, check out the project's GitHub repo at http://github.com/over2sd/stager.");
}
print ".";

=item castShow HANDLE CONTAINER SHOWID TROUPEID
Displays the cast of a selected show within CONTAINER.
No return value.
=cut
sub castShow {
	my ($dbh,$target,$sid,$tid) = @_;
	$target->empty(); # VBox function, clear list
	unless (defined $sid and defined $tid) { $target->insert( Label => text => "An error occurred: Invalid role or troupe given.\nIDs could not be secured for both values.", wordWrap => 1, height => 60, pack => { fill => 'both' }, ); return; }
	$target->insert( Label => text => "Cast/crew of a " . FlexSQL::getTroupeByID($dbh,$tid) . " production of " . FlexSQL::getShowByID($dbh,$sid) . ":" );
	my $st = "SELECT mid,role FROM cv WHERE work=? AND troupe=? ;";
	my @parms = ($sid,$tid);
	my $res = FlexSQL::doQuery(4,$dbh,$st,@parms);
	foreach (@$res) {
		my $mid = $$_[0];
		my $name = getMemNameByID($dbh,$mid);
		my $row = labelBox($target,"$$_[1]: ",'row','h');
		my $gui = getGUI();
		$row->insert( Button => text => $name, onClick => sub { showRoleEditor($gui,$dbh,$mid); }, font => applyFont('button'), );
	}
}
print ".";

=item getMemNameByID HANDLE MEMBER
Using the supplied database handle HANDLE, retrieves the name of member
#MEMBER.
Returns a SCALAR containing the member's name
=cut
sub getMemNameByID {
	my ($dbh,$mid) = @_;
	my $text;
	my $st = "SELECT givname,famname FROM member WHERE mid=?;";
	my $res = FlexSQL::doQuery(6,$dbh,$st,$mid);
	return '' unless defined $res;
	# TODO?: add a column allowing name order to be stored for i18n?
	$text = (FIO::config('UI','eastname') ? "$$res{famname} $$res{givname}" : "$$res{givname} $$res{famname}");
	return $text;
}
print ".";

=item getOpts
mkOptBox() uses the hash returned by this function to build its dialog
automagically, so be very careful about editing this hash. Lines have
this format:
	POSITION => [TYPE,LABEL,CONFIG KEY,DEFAULT (or first choice),OTHER CHOICES],
Returns a HASH containing the options the Options dialog can modify.
=cut
sub getOpts {
	# First hash key (when sorted) MUST be a label containing a key that corresponds to the INI Section for the options that follow it!
	# EACH Section needs a label conaining the Section name in the INI file where it resides.
	my %opts = (
		'000' => ['l',"General",'Main'],
		'001' => ['c',"Save window positions",'savepos'],
		'004' => ['c',"Errors are fatal",'fatalerr'],
		'002' => ['n',"Age of Majority",'guarage',18,10,35,1],

#		'005' => ['l',"Import/Export",'ImEx'], # commented until it does something

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
#		'035' => ['c',"Show supporter tab",'showsupportlist'],
##		'042' => ['x',"Foreground color: ",'fgcol',"#00000"],
##		'043' => ['x',"Background color: ",'bgcol',"#CCCCCC"],
		'036' => ['c',"Show thumbnails on buttons",'headthumb'],
		'037' => ['n',"Scale factor of thumbnails",'thumbscale',0.25,0.1,0.95,0.05,0.25],
		'038' => ['n',"Number of columns for face tab",'facecols',4,1,100,1,10],
		'039' => ['c',"Names on buttons as 'first last', not 'last, first'",'commalessname'],
		'03a' => ['c',"Family name comes first",'eastname'],
		'040' => ['x',"Tooltip background color: ",'hintback',"#CC9999"],
		'041' => ['x',"Tooltip foreground color: ",'hintfore',"#000033"],

		'050' => ['l',"Fonts",'Font'],
		'054' => ['f',"Tab font/size: ",'label'],
		'051' => ['f',"General font/size: ",'body'],
#		'053' => ['f',"Special font/size: ",'special'], # for lack of a better term
		'055' => ['f',"Tooltip font/size: ",'hint'],
		'056' => ['f',"Button font/size: ",'button'],

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
		'075' => ['t',"Cast by Age:",'cba'],
#		'076' => ['t',"Supporters:",'ang'],
		'084' => ['t',"Options dialog",'options'],
		'080' => ['t',"Edit member save button",'okedit'],
		'081' => ['t',"Add member save button",'okadd'],
		'082' => ['t',"User details dialog title",'udetail'],
		'083' => ['t',"Guardian dialog title",'guarinf'],

		'ff0' => ['l',"Debug Options",'Debug'],
		'ff1' => ['c',"Colored terminal output",'termcolors'],
	);
	return %opts;
}
print ".";

=item refreshUI GUI HANDLE
This function refreshes the user interface. I think.
=cut
sub refreshUI {
	my ($gui,$dbh) = @_;
	$gui = getGUI() unless (defined $$gui{status});
	$dbh = FlexSQL::getDB() unless (defined $dbh);
	print "Refreshing UI...\n";
	populateMainWin($dbh,$gui,1);
}
print ".";

=item editMember
Displays a dialog for editing a member.
No return value.
=cut
sub editMember {
	my ($gui,$dbh,$user) = @_;
	editMemberDialog($gui,$dbh,(config('Custom','okedit') or "Save"),1,undef,%$user);
}
print ".";

=item addMember
Displays a dialog for adding or editing a member.
No return value.
=cut
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
		onClick => sub { $addbox->destroy(); return; },
		hint => "Cancel $buttontext.",
		font => applyFont('button'),
	);
	my $namebox = $vbox->insert( HBox => name => 'namebox', pack => { expand => 1, }, );
	my $nbox1 = labelBox($namebox,"Given Name",'n1','v');
	my $nbox2 = labelBox($namebox,"Family Name",'n2','v');
	my $givname = $nbox1->insert( InputLine => maxLen => 23, text => ($user{givname} or ''), hint => "Enter the member's first (given) name.", );
	my $famname = $nbox2->insert( InputLine => maxLen => 28, text => ($user{famname} or ''), hint => "Enter the member's last (family) name.", );
	my $phonbox = $vbox->insert( HBox => name => 'phones', pack => { fill => 'x', expand => 1, }, );
	my $hpbox = labelBox($phonbox,"Home Phone",'pb1','v');
	my $hphone = $hpbox->insert( InputLine => maxLen => 10, width => 150, text => ($user{hphone} or '##########'), hint => "Enter the member's home phone number.", );
	my $mpbox = labelBox($phonbox,"Mobile/Work Phone",'pb2','v');
	my $mphone = $mpbox->insert( InputLine => maxLen => 10, width => 150, text => ($user{mphone} or '##########'), hint => "Enter the member's mobile or work phone number.", );
	$vbox->insert( Label => text => "E-mail Address" );
	my $email = $vbox->insert( InputLine => maxLen => 254, text => ($user{email} or config('InDef','email') or 'user@example.com'), pack => { fill => 'x', }, hint => "Enter the member's electronic mail address.", );
	my $abox = labelBox($vbox,"Birthdate",'abox','h',boxfill => 'x');
# TODO: Add calendar button for date of birth? (if option selected?)
	my $dob = $abox->insert( InputLine => maxLen => 10, width => 120, text => ($user{dob} or ''), hint => "Enter the member's date of birth\nas YYYY-MM-DD (hyphens optional)", );
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
	my $guar = $abox->insert( Button => text => $guarbuttext, enabled => $guarneed, onClick => sub { %guardian = guardianDialog($$gui{mainWin},($guarlabel->text or $guartext)); $guarlabel->text("Guardian: " . ($guardian{name} or 'unknown') . " " . ($guardian{phone} or '')); $updateguar |= 2; }, hint => "If the member is a minor,\nclick this button to set information\nabout the member's guardian.", font => applyFont('button'), );
	$dob->onChange( sub {
		return if (length($dob->text) < 8); # no point checking an incomplete date
		$guarneed = ((Common::getAge($dob->text) or 0) < (config('Main','guarage') or "18"));
		$guar->text($guarneed ? "Guardian" : "Adult");
		$guar->enabled($guarneed);
	}, );
	$guarlabel = $vbox->insert( Label => text => $guartext, hint => "If a guardian has been set, the name and phone number will appear here.\nClick the 'Guardian' button to set this field.", );
	my $gbox = labelBox($vbox,"Gender",'gbox','h',boxfill => 'x');
	my $gender = $gbox-> insert( XButtons => name => 'gen', pack => { fill => "none", expand => 0, }, hint => "Click a button to set the member's sex.", font => applyFont('button'), );
	$gender->arrange("left"); # line up buttons horizontally (TODO: make this an option in the options hash? or depend on text length?)
	my @presets = ("M","M","F","F");
	my $current = ($user{gender} or "M"); # pull current value from config
	$current = Common::findIn($current,@presets); # by finding it in the array
	$current = ($current == -1 ? scalar @presets : $current/2); # and dividing its position by 2 (behavior is undefined if position is odd)
	$gender-> build("",$current,@presets); # turn key:value pairs into exclusive buttons
	$vbox->insert( Label => text => "Street Address" );
	my $address = $vbox->insert( InputLine => maxLen => 253, text => ($user{address} or ''), pack => { fill => 'x', }, hint => "Enter the member's street address.", );
	my $cbox = $vbox->insert( HBox => name => 'citybox', pack => { expand => 1, }, );
	my $cbox1 = labelBox($cbox,"City",'c1','v',boxfill => 'x', labfill => 'x');
	my $cbox2 = labelBox($cbox,"State",'c2','v');
	my $cbox3 = labelBox($cbox,"ZIP",'c3','v');
	my $city = $cbox1->insert( InputLine => maxLen => 99, text => ($user{city} or config('InDef','city') or ''), pack => { fill => 'x', expand => 1}, hint => "Enter the member's city.", );
	my $state = $cbox2->insert( InputLine => maxLen => 3, text => ($user{state} or config('InDef','state') or ''), width => 45, hint => "Enter the member's state or province.", );
	my $zip = $cbox3->insert( InputLine => maxLen => 10, text => ($user{zip} or config('InDef','ZIP') or ''), hint => "Enter the member's ZIP or other postal code.", );
	my $mtbox = labelBox($vbox,"Type:",'rb','h');
	my $memtype = ($user{memtype} or 0);
	my $cbcast = $mtbox->insert( CheckBox => text => "Cast", checked => ($memtype & 1), hint => "Check this if the member is willing to act on stage.", );
	my $cbcrew = $mtbox->insert( CheckBox => text => "Crew", checked => ($memtype & 2), hint => "Check this if the member is willing to work offstage.", );
	my $imbox = labelBox($vbox,"Headshot filename",'im','h', boxex => 1, boxfill => 'x');
	my $img = $imbox->insert( InputLine => maxLen => 256, text => ($user{imgfn} or 'noface.png'), pack => { fill => 'x', expand => 1, }, hint => "Enter the name of the file you (will) put in the img/ directory\nshowing the member's head and shoulders.\nLeave blank if no photo is available.", );
	$imbox->insert( Button => text => "Choose", font => applyFont('button'), onClick => sub { my $o = Prima::OpenDialog->new( filter => [['Portable Network Graphics' => '*.png'],['All' => '*'],],directory => 'img/.',); $img->text = $o->fileName if $o->execute; }, hint => "Click here to choose a file you've already put in the img/ directory.", );
	$vbox->insert( Button =>
		text => $buttontext,
		hint => "Click here to submit the form.",
		font => applyFont('button'),
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
	my ($parent,$string) = @_;
	$string =~ m/Guardian: (.+) ([0-9]{7,10})/;
	my %defaults;
	$defaults{name} = $1 if (defined $1);
	$defaults{phone} = $2 if (defined $2);
	return askbox($parent,(config('Custom','guarinf') or "Guardian Info"),\%defaults,name=>"Guardian Name",phone=>"Guardian Phone #");
}
print ".";

sub askbox { # makes a dialog asking for the answer(s) to a given list of questions, either a single scalar, or an array of key/question pairs whose answers will be stored in a hash with the given keys.
	my ($parent,$tibar,$defaults,@questions) = @_; # using an array allows single scalar question and preserved order of questions asked.
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
		$ans->text($$defaults{$key}) if exists $$defaults{$key};
		$ans->onChange( sub { $answers{$key} = $ans->text; } );
		$i += 2;
	}
	my $spacer = $vbox->insert( Label => text => " ", pack => { fill => 'both', expand => 1 }, );
	my $fresh = Prima::MsgBox::insert_buttons( $askbox, $buttons, $extras); # not reinventing wheel
	$fresh->set( font => applyFont('button'), );
	$askbox->execute;
	if ($numq == 0) {
		return $answers{one};
	} else {
		return %answers;
	}
}
print ".";

Common::registerErrors('PGUI::storeGuardian','[E] Statement preparation failed.','[E] Statement execution failed.');
=item storeGuardian GUI HANDLE UPDATE HASHREF
Given a HASHREF containing information about the guardian, stores or 
updates the guardian's information in the database.
Registers error codes.
Returns 0 on success.
=cut
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
	my $text = (($imagebutton & 1 or config('UI','commalessname')) ? "$a[0] $a[1]" : "$a[1], $a[0]"); # concatenate famname, givname and put a label in the window.
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
		my $button = $target->insert( Button => text => $label,
			onClick => sub { showRoleEditor($gui,$dbh,$id); }, # link button to role editor
			alignment => ta::Left,
			image => $headshot,
			flat => $image & 4,
			vertical => $image & 1,
		);
		applyFont('button',$button);
		$button->pack( fill => 'x' );
		$button->pack( expand => 1 ) if $image & 1;
		if ($image & 2) { $button->imageScale( (config('UI','thumbscale') or 0.25) ); }
	} else{
		$target->insert( Button =>
			text => $label,
			alignment => ta::Left,
			pack => { fill => 'x' },
			font => applyFont('button'),
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
	my $cmd = "SELECT givname,famname,mid,gender,memtype,imgfn FROM member WHERE memtype & 1 AND gender=? AND (dob IS NULL OR ?<dob AND dob<?) ORDER BY dob;";
	use DateTime;
	my ($mindob,$maxdob) = Common::DoBrangefromAges(DateTime->now(),$n,$x,1);
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
			putButtons($_,$row,$row,$row,$gui,$dbh,5);
			$column++;
			if ($column > (config('UI','facecols') or 4)) {
				$column = 0; # reset column, triggering new row creation.
			}
		}
	}
	$$gui{tabbar}->pageIndex(1);
}
print ".";

Common::registerErrors('PGUI::savePos',"[E] savePos was not passed a valid object!","[W] savePos requires an object to measure.");
=item savePos WINDOW
Given a WINDOW (or other oject with a size and origin), saves its
position and size in the configuration file.
Registers error codes.
Returns 0 on success.
=cut
sub savePos {
	my $o = shift;
	return 2 unless (defined $o);
	my ($w,$h,$l,$t) = ($o->size,$o->origin);
	unless (defined $w && defined $h && defined $t && defined $l) {
		return 1;
	}
	config('Main','width',$w);
	config('Main','height',$h);
	config('Main','top',$t);
	config('Main','left',$l);
	FIO::saveConf();
	return 0;
}
print ".";

=item applyFont STYLE WIDGET
Attempts to get the font called STYLE from the configuration's Font
section (as a name and size) and apply it as a Prima font to the given
Prima WIDGET.
If no WIDGET is given, returns the font profile. This is useful in
object creation without a reference saved.
=cut
sub applyFont {
	my ($key,$widget) = @_;
	return undef unless (defined $key); # just silently fail if no key given.
	unless (defined $widget) { return FontRow->stringToFont(FIO::config('Font',$key) or FIO::config('Font','body') or ""); } # return the font if no wifget given (for use in insert() profiles).
	$widget->set( font => FontRow->stringToFont(FIO::config('Font',$key) or ""),); # apply the font; Yay!
}
print ".";

print " OK; ";
1;
