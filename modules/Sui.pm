package Sui; # Self - Program-specific data storage
print __PACKAGE__;

=head1 Sui

Keeps common modules as clean as possible by storing program-specific
data needed by those common-module functions in a separate file.

=head2 passData STRING

Passes the data identified by STRING to the caller.
Returns some data block, usually an arrayref or hashref, but possibly
anything. Calling programs should be carefully written to expect what
they're asking for.

=cut

my %data = (
	dbname => 'stager',
	dbhost => 'localhost',
	tablekeys => {
		member => ['famname','givname','hphone','mphone','email','gender','address','city','state','zip','notes','dob','memtype','imgfn'],
		cv => ['mid','work','role','year','month','troupe','rtype'],
		guardian => ['mid','name','phone','rel']
		},
	tableids => { member => "mid", cv => "rid", guardian => 'mid' },
);

sub passData {
	my $key = shift;
	return $data{$key} or undef;
}
print ".";

sub getMembers {
	my ($dbh,$mtype,%exargs) = @_;
	my $st = "SELECT givname, famname, mid, gender, memtype, imgfn FROM member ORDER BY famname, givname;";
	my $res = FlexSQL::doQuery(4,$dbh,$st);
	return $res;
}
print ".";

sub getMemberByID {
	my ($dbh,$mid,%exargs) = @_;
	my $st = "SELECT * FROM member WHERE mid=?;";
	my $res = FlexSQL::doQuery(6,$dbh,$st,$mid);
	return $res unless $DBI::err;
	warn $DBI::errstr;
	return {};
}
print ".";

my %shows;
sub getShowByID {
	my ($dbh,$sid) = @_;
	unless (keys %shows and exists $shows{"$sid"}) {
		getShowList($dbh);
	}
	return $shows{"$sid"};
}
print ".";

sub getShowList {
	my $dbh = shift;
	my $st = "SELECT wid,sname FROM work;";
	my $res = FlexSQL::doQuery(3,$dbh,$st,'wid');
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
	my $res = FlexSQL::doQuery(3,$dbh,$st,'tid');
	foreach (%$res) {
		my %row = %$_;
		$troupes{$row{tid}} = $row{tname};
	}
	return \%troupes;
}
print ".";

print "OK; ";
1;
