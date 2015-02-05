# Module for SQL database interactions (other DBs may be added later)
package FlexSQL;
print __PACKAGE__;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(getDB closeDB);

use FIO qw( config );

my $DBNAME = 'stager';
my $DBHOST = 'localhost';

# DB wrappers that call SQL(ite) functions, depending on which the user has chosen to use for a backend.
my $dbh;
sub getDB {
	if (defined $dbh) { return $dbh; }
	my ($dbtype) = shift;
	if ($dbtype eq "0") { return undef; } # flag for not creating DB if not available
	unless (defined $dbtype) { $dbtype = FIO::config('DB','type'); } # try to save
	use DBI;
	if ($dbtype eq "L") { # for people without access to a SQL server
		$dbh = DBI->connect( "dbi:SQLite:$DBNAME.dbl" ) || return undef,"Cannot connect: $DBI::errstr";
#		$dbh->do("SET NAMES 'utf8mb4'");
		print "SQLite DB connected.";
	} elsif ($dbtype eq "M") {
		my $host = shift || "$DBHOST";
		my $base = shift || "$DBNAME";
		my $password = shift || '';
		my $username = shift || whoAmI();
		# connect to the database
		my $flags = { mysql_enable_utf8mb4 => 1 };
		if ($password ne '') {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username,$password,$flags) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		} else {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username,undef,$flags) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		}
		$dbh->do("SET NAMES 'UTF8MB4'");
	} else { #bad/no DB type
		return undef,"Bad/no DB type passed to getDB! (" . ($dbtype or "undef") . ")";
	}
	return $dbh,"";
}
print ".";

sub closeDB {
	my $dbh = shift or getDB(0);
	if (defined $dbh) { $dbh->disconnect; }
	print "Database closed.";
}
print ".";

sub whoAmI {
	if (($^O ne "darwin") && ($^O =~ m/[Ww]in/)) {
		print "Asking for Windows login...\n";
		my $canusewin32 = eval { require Win32; };
		return Win32::LoginName if $canusewin32;
		return $ENV{USERNAME} || $ENV{LOGNAME} || $ENV{USER} || "player1";
	};
	return $ENV{LOGNAME} || $ENV{USER} || getpwuid($<); # try to get username by various means if not passed it.
}
print ".";

# functions for creating database
sub makeDB {
	my ($dbtype) = shift; # same prep work as regular connection...
	my $host = shift || 'localhost';
	my $base = shift || 'stager';
	my $password = shift || '';
	my $username = shift || whoAmI();
	use DBI;
	my $dbh;
	print "Creating database...";
	if ($dbtype eq "L") { # for people without access to a SQL server
		$dbh = DBI->connect( "dbi:SQLite:stager.dbl" ) || return undef,"Cannot connect: $DBI::errstr";
		my $newbase = $dbh->quote_identifier($base); # just in case...
		unless ($dbh->func("createdb", $newbase, 'admin')) { return undef,$DBI::errstr; }
	} elsif ($dbtype eq "M") {
		# connect to the database
		my $flags = { mysql_enable_utf8mb4 => 1 };
		if ($password ne '') {
			$dbh = DBI->connect("DBI:mysql::$host",$username, $password,$flags) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		} else {
			$dbh = DBI->connect("DBI:mysql::$host",$username,undef,$flags) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		}
		my $newbase = $dbh->quote_identifier($base); # just in case...
		unless(doQuery(2,$dbh,"CREATE DATABASE $newbase")) { return undef,$DBI::errstr; }
	}	
	print "Database created.";
	$dbh->disconnect();
	if ($dbtype eq "L") { # for people without access to a SQL server
		$dbh = DBI->connect( "dbi:SQLite:stager.dbl" ) || return undef,"Cannot connect: $DBI::errstr";
	} elsif ($dbtype eq "M") {
		# connect to the database
		my $flags = { mysql_enable_utf8mb4 => 1 };
		if ($password ne '') {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username,$password,$flags) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		} else {
			$dbh = DBI->connect("DBI:mysql:$base:$host",$username,undef,$flags) ||
				return undef, qq{DBI error from connect: "$DBI::errstr"};
		}
	}
	return $dbh,"OK";
}
print ".";

sub makeTables { # used for first run
	my ($dbh) = shift; # same prep work as regular connection...
	print "Creating tables...";
	open(TABDEF, "<stager.msq"); # open table definition file
	my @cmds = <TABDEF>;
	print "Importing " . scalar @cmds . " lines.";
	foreach my $i (0 .. $#cmds) {
		my $st = $cmds[$i];
		if ('SQLite' eq $dbh->{Driver}->{Name}) {
			$st =~ s/ UNSIGNED//g; # SQLite doesn't (properly) support unsigned?
			$st =~ s/ AUTO_INCREMENT//g; #...or auto_increment?
		}
		my $error = doQuery(2,$dbh,$st);
#		print $i + 1 . ($error ? ": $st\n" : "" );
		print ".";
		if($error) { return undef,$error; }
	}
	return $dbh,"OK";
}
print ".";

# functions for accessing database
sub doQuery {
	my ($qtype,$dbh,$statement,@parms) = @_;
	my $realq;
#	print "Received '$statement' ",join(',',@parms),"\n";
	unless (defined $dbh) {
		Pdie("Baka! Send me a database, if you want data.");
	}
	my $safeq = $dbh->prepare($statement);
	if ($qtype == -1) { unless (defined $safeq) { return 0; } else { return 1; }} # prepare only
	unless (defined $safeq) { warn "Statement could not be prepared! Aborting statement!\n"; return undef; }
	if($qtype == 0){ # expect a scalar
		$realq = $safeq->execute(@parms);
		unless ("$realq" eq "1") {
#			print " result: $realq - ".$dbh->errstr;
			return "";
		}
		$realq = $safeq->fetchrow_arrayref();
		$realq = @{ $realq }[0];
	} elsif ($qtype == 1){
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_arrayref({ Slice => {} });
	} elsif ($qtype == 2) {
		$realq = $safeq->execute(@parms); # just execute and return the result or the error
		if($realq =~ m/^[0-9]+$/) {
			return $realq; 
		} else {
			return $dbh->errstr;
		}
	} elsif ($qtype == 3){
		unless (@parms) {
			warn "Required field not supplied for doQuery(3). Give field name to act as hash keys in final parameter.\n";
			return ();
		}
		my $key = pop(@parms);
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_hashref($key);
	} elsif ($qtype == 4){ # returns arrayref containing arrayref for each row
		$safeq->execute(@parms);
		$realq = $safeq->fetchall_arrayref();
	} elsif ($qtype == 5){
		$safeq->execute(@parms);
		$realq = $safeq->fetchrow_arrayref();
	} elsif ($qtype == 6){ # returns a single row in a hashref; use with a primary key!
		$safeq->execute(@parms);
		$realq = $safeq->fetchrow_hashref();
	} else {
		warn "Invalid query type";
	}
	return $realq;
}
print ".";

sub table_exists {
	my ($dbh,$table) = @_;
	my $st = qq(SHOW TABLES LIKE ?;);
	if ('SQLite' eq $dbh->{Driver}->{Name}) { $st = qq(SELECT tid FROM $table LIMIT 0); return doQuery(-1,$dbh,$st); }
	my $result = doQuery(0,$dbh,$st,$table);
	return (length($result) == 0) ? 0 : 1;
}
print ".";

sub prepareFromHash {
	my ($href,$table,$update,$extra) = @_;
	my %tablekeys = (
		member => ['famname','givname','hphone','mphone','email','age','address','city','state','zip','notes','dob','memtype'],
		cv => ['mid','show','role','year','month','troupe']
	);
	my ($upcolor,$incolor,$basecolor) = ("","","");
	if ((FIO::config('Debug','termcolors') or 0)) {
		use Common qw( getColorsbyName );
		$upcolor = Common::getColorsbyName("yellow");
		$incolor = Common::getColorsbyName("purple");
		$basecolor = Common::getColorsbyName("base");
	}
	my %ids = ( member => "mid", cv => "rid");
	my $idcol = $ids{$table} or return 1,"ERROR","Bad table name passed to prepareFromHash";
	my %vals = %$href;
	my @parms;
	my $cmd = ($table eq "member" ? "member" : $table eq "cv" ? "cv" : "bogus");
	if ($cmd eq "bogus") { return 1,"ERROR","Bogus table name passed to prepareFromHash"; }
	my @keys = @{$tablekeys{$table}};
	unless ($update) {
		my $valstxt = "VALUES (";
		$cmd = "INSERT INTO $cmd (";
		my @cols;
#		push(@parms,$vals{$idcol});
#		push(@cols,$idcol);
		print "$incolor";
		foreach (keys %vals) {
			unless (Common::findIn($_,@keys) < 0) {
				push(@cols,$_); # columns
				push(@parms,$vals{$_}); # parms
				print ".";
			}
		}
		print "$basecolor";
		unless(@parms) { return 2,"ERROR","No parameters were matched with column names."; }
		$cmd = "$cmd" . join(",",@cols);
		if(@cols) { $valstxt = "$valstxt?" . (",?" x $#cols) . ")"; }
		$cmd = "$cmd) $valstxt";
	} else {
		$cmd = "UPDATE $cmd SET ";
		print "$upcolor";
		foreach (keys %vals) {
			unless (Common::findIn($_,@keys) < 0) {
				$cmd = "$cmd$_=?, "; # columns
				push(@parms,$vals{$_}); # parms
				print ".";
			}
		}
		print "$basecolor";
		unless(@parms) { return 2,"ERROR","No parameters were matched with column names."; }
		$cmd = substr($cmd,0,length($cmd)-2); # trim final ", "
		$cmd = "$cmd WHERE $idcol=?";
		push(@parms,$vals{$idcol});
	}
	return 0,$cmd,@parms; # Normal completion
}
print ".";

sub getMembers {
	my ($dbh,$mtype,%exargs) = @_;
	my $st = "SELECT givname, famname, mid FROM member ORDER BY famname;";
	my $res = doQuery(4,$dbh,$st);
	return $res;
}
print ".";

sub getMemberByID {
	my ($dbh,$mid,%exargs) = @_;
	my $st = "SELECT * FROM member WHERE mid=?;";
	my $res = doQuery(6,$dbh,$st,$mid);
	return $res unless $DBI::err;
	warn $DBI::errstr;
	return {};
}
print ".";

my %shows;
sub getShowByID {
	my ($dbh,$sid) = @_;
	unless (keys %troupes and exists $shows{"$sid"}) {
		getShowList($dbh);
	}
	return $shows{"$sid"};
}
print ".";

sub getShowList {
	my $dbh = shift;
	my $st = "SELECT wid,sname FROM work;";
	my $res = doQuery(3,$dbh,$st,'wid');
	foreach (%$res) {
		my %row = %$_;
		$shows{$row{wid}} = $row{sname};
	}
	return \%shows;
}
print ".";

my %troupes;
sub getTroupeByID {
	my ($dbh,$tid) = @_;
	unless (keys %troupes and exists $troupes{"$tid"}) {
		getTroupeList($dbh);
	}
	return $troupes{"$tid"};
}
print ".";

sub getTroupeList {
	my $dbh = shift;
	my $st = "SELECT tid,tname FROM troupe;";
	my $res = doQuery(3,$dbh,$st,'tid');
	foreach (%$res) {
		my %row = %$_;
		$troupes{$row{tid}} = $row{tname};
	}
	return \%troupes;
}
print ".";

print " OK; ";
1;
