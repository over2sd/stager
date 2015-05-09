package Common;
print __PACKAGE__;

sub getBit { # returns bool
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	return ($mask & $pos) == $pos ? 1 : 0;
}
print ".";

sub setBit { # returns mask
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	return $mask | $pos;
}

sub unsetBit { # returns mask
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	return $mask ^ $pos;
}
print ".";

sub toggleBit { # returns mask
	my ($pos,$mask) = @_;
	$pos = 2**$pos;
	$pos = $mask & $pos ? $pos : $pos * -1;
	return $mask + $pos;
}
print ".";

sub get {
	my ($hr,$key,$dv) = @_;
	if ((not defined $hr) or (not defined $key) or (not defined $dv)) {
		$hr = 'undef' unless defined $hr; $key = 'undef' unless defined $key; $dv = 'undef' unless defined $dv;
		warn "Safe getter called without required parameter(s)! ($hr,$key,$dv)";
		return undef;
	}
	if (exists $hr->{$key}) {
		return $hr->{$key};
	} else {
		return $dv;
	}
}
print ".";

# I've pulled these three functions into so many projects, I ought to release them as part of a library.
sub getColorsbyName {
	my $name = shift;
	my @colnames = qw( base red green yellow blue purple cyan ltred ltgreen ltyellow ltblue pink ltcyan white bluong blkrev gray );
	my $ccode = -1;
	++$ccode until $ccode > $#colnames or $colnames[$ccode] eq $name;
	$ccode = ($ccode > $#colnames) ? 0 : $ccode;
	return getColors($ccode);
}
print ".";

sub getColors{
	if (0) { # TODO: check for terminal color compatibility
		return "";
	}
	my @colors = ("\033[0;37;40m","\033[0;31;40m","\033[0;32;40m","\033[0;33;40m","\033[0;34;40m","\033[0;35;40m","\033[0;36;40m","\033[1;31;40m","\033[1;32;40m","\033[1;33;40m","\033[1;34;40m","\033[1;35;40m","\033[1;36;40m","\033[1;37;40m","\033[0;34;47m","\033[7;37;40m","\033[1;30;40m");
	my $index = shift;
	if ($index >= scalar @colors) {
		$index = $index % scalar @colors;
	}
	if (defined($index)) {
		return $colors[int($index)];
	} else {
		return @colors;
	}
}
print ".";

sub findIn {
	my ($v,@a) = @_;
	if ($debug > 0) {
		use Data::Dumper;
		print ">>".Dumper @a;
		print "($v)<<";
	}
	unless (defined $a[$#a] and defined $v) {
		use Carp qw( croak );
		my @loc = caller(0);
		my $line = $loc[2];
		@loc = caller(1);
		my $file = $loc[1];
		my $func = $loc[3];
		croak("FATAL: findIn was not sent a \$SCALAR and an \@ARRAY as required from line $line of $func in $file. Caught");
		return -1;
	}
	my $i = 0;
	while ($i < scalar @a) {
		print ":$i:" if $debug > 0;
		if ("$a[$i]" eq "$v") { return $i; }
		$i++;
	}
	return -1;
}
print ".";

sub nround {
	my ($prec,$value) = @_;
	use Math::Round qw( nearest );
	my $target = 1;
	while ($prec > 0) { $target /= 10; $prec--; }
	while ($prec < 0) { $target *= 10; $prec++; } # negative precision gives 10s, 100s, etc.
	if ($debug) { print "Value $value rounded to $target: " . nearest($target,$value) . ".\n"; }
	return nearest($target,$value);
}
print ".";

sub revGet { # works best on a 1:1 hash
	my ($target,$default,%hash) = @_;
	foreach (keys %hash) {
		return $_ if ($target eq $hash{$_});
	}
	return $default;
}
print ".";

=item indexOrder()
	Expects a reference to a hash that contains hashes of data as from fetchall_hashref.
	This function will return an array of keys ordered by whichever internal hash key you provide.
	@array from indexOrder($hashref,$]second-level key by which to sort first-level keys[)
=cut
sub indexOrder {
	my ($hr,$orderkey) = @_;
	my %hok;
	foreach (keys %$hr) {
		my $val = $_;
		my $key = qq( $$hr{$_}{$orderkey} );
		$hok{$key} = [] unless exists $hok{$key};
		push(@{ $hok{$key} },$val); # handles identical values without overwriting key
	}
	my @keys;
	foreach (sort keys %hok){
		push(@keys,@{ $hok{$_} });
	}
	return @keys;
}
print ".";

sub shorten {
	my ($text,$len,$endlen) = @_;
	return $text unless (defined $text and length($text) > $len); # don't do anything unless text is too long.
	my $part2length = ($endlen or 7); # how many characters after the ellipsis?
	my $part1length = $len - ($part2length + 3); # how many characters before the ellipsis?
	if ($part1length < $part2length) { # if string would be lopsided (end part longer than beginning)
		$part2length = 0; # end with ellipsis instead of string ending
		$part1length = $len - 3;
	}
	if ($part1length < 7 or $part1length + 3 > $len - $part2length) { # resulting string is too short, or doesn't chop off enough for ellipsis to make sense.
		warn "Shortening string of length " . length($text) . " ($text) to $len does not make sense. Skipping.\n";
		return $text;
	}
	my $part1 = substr($text,0,$part1length); # part before ...
	my $part2 = substr($text,-$part2length); # part after ...
	$text = "$part1...$part2"; # strung together with ...
	return $text;
}
print ".";

sub getAge {
	my $dob = shift; # expects date as "YYYY-MM-DD" or "YYYYMMDD"
	use DateTime;
	return undef unless (defined $dob and $dob ne '');
	$dob=~/([0-9]{4})-?([0-9]{2})-?([0-9]{2})/; # DATE field format from MySQL. May not work for other sources of date.
	my $start = DateTime->new( year => $1, month => $2, day => $3);
	my $end = DateTime->now;
	my $age = $end - $start;
	return $age->in_units('years');
}
print ".";

sub stripDOBdashes {
	my $dob = shift; # expects date as "YYYY-MM-DD" or "YYYYMMDD"
	$dob=~/([0-9]{4})-?([0-9]{2})-?([0-9]{2})/; # DATE field format from MySQL. May not work for other sources of date.
	return "$1$2$3";
}
print ".";

=item DoBrangefromAges MINAGE MAXAGE
Given a minimum age MINAGE and an optional maximum age MAXAGE, this
function returns two strings in YYYY-MM-DD format, suitable for use in
SQL queries, e.g., WHERE ?<dob AND dob<?, using the return values in
order as parameters. If no MAXAGE is given, date range is for MINAGE
only.
=cut
sub DoBrangefromAges {
	my ($agemin,$agemax,$inclusive) = @_;
	use DateTime;
	die "[E] Minimum age omitted in DoBrangefromAges" unless (defined $agemin and $agemin ne '');
	$agemin = int($agemin);
	$agemax = int($agemin) unless defined $agemax;
	$agemax = int($agemax);
	$inclusive = ($inclusive ? $inclusive : 0);
	my ($maxdob,$mindob) = (DateTime->now,DateTime->now);
	$maxdob->subtract(years => $agemin);
	$mindob->subtract(years => $agemax + 1);
	return $mindob->ymd('-'),$maxdob->ymd('-');
}
print ".";

=item registerErrors FUNCTION ARRAY
Given an ARRAY of error texts and a FUNCTION name, stores error texts
for later display on error.
=cut
my %errorcodelist;
sub registerErrors {
	my ($func,@errors) = @_;
	$errorcodelist{$func} = ['',] unless defined $errorcodelist{$func}; # prepare if no codes on record.
#	print "\n - Registering error codes for $func:"; # "\n";
	my ($col,$base) = (getColors(5),getColorsbyName('base'));
	foreach (0 .. $#errors) {
#		printf(" %d",$_ + 1); # "\t" . $_ + 1 . ": $errors[$_]\n";
		$errorcodelist{$func}[$_ + 1] = $errors[$_];
		print "$col-$base";
	}
#	print "\n";
}
print ".";

=item registerZero FUNCTION DISPLAY
This function registers errorcode for result of 0. Useful for either
success or failure code of 0 (e.g. 0 results).
=cut
sub registerZero {
	my ($func,$text) = @_;
	$errorcodelist{$func} = ['',] unless defined $errorcodelist{$func}; # prepare if no codes on record.
	$errorcodelist{$func}[0] = $text;
	my ($col,$base) = (getColors(6),getColorsbyName('base'));
	print "$col+$base";
}
print ".";

sub errorOut {
	my ($func,$code,%args) = @_;
	my $str = ($args{string} or undef);
	my $trace = ($args{trace} or 0);
	unless (defined $func and defined $code) {
		warn "errorOut called without required parameters";
		return 1;
	}
#		use FIO qw( config ); # TODO: Fail gracefully here (eval?)
	my $fatal = ( $args{fatal} or FIO::config('Main','fatalerr') or 0 );
	my $color = ( $args{color} or FIO::config('Debug','termcolors') or 1 );
	my $error = qq{errorOut could not find error code $code associated with $func};
	unless (defined $errorcodelist{$func} or $func eq 'inline') {
		warn $error;
		return 2;
	}
	my @list = ($func eq 'inline' ? (($args{string} or "[E] Oops!")) : @{ $errorcodelist{$func} });
	unless (int($code) < scalar @list) {
		if ($list[$#list] =~ m/%d/) { # Test for %d in final error code.
			$code = $#list; # If found, use it as generic error message.
		} else {
			warn $error;
			return 2;
		}
	}
	# actually registered error codes:
	$error = $list[int($code)];
	if ($trace) {
		use Carp qw( croak );
		my @loc = caller(0);
		my $line = $loc[2];
		@loc = caller(1);
		my $file = $loc[1];
		my $sub = $loc[3];
		$error = qq{$error at line $line of $sub in $file.\n};
	}
	$error =~ s/%d/$code/; # replace %d with $code
	if (defined $str) {
		$str = $func if ($str eq '%self');
		$error =~ s/%s/$str/; # replace %s with given string
	}
	if ($error =~ m/^\[E\]/) { # error
		$color = ($color ? 1 : 0);
		($fatal ? die errColor($error,$color) : warn errColor($error,$color));
	} elsif ($error =~ m/^\[W\]/) { # warning
		$color = ($color ? 3 : 0);
		($fatal ? warn errColor($error,$color) : print errColor($error,$color));
	} elsif ($error =~ m/^\[I\]/) { # information
		$color = ($color ? 2 : 0);
		print errColor($error . "\n",$color);
	} else { # unformatted (malformed) error
		print $error;
	}
}
print ".";

sub errColor {
	my ($string,$color) = @_;
	return $string unless $color; # send back uncolored
	# TODO: check for numeric value and use getColorsbyName if not numeric
	my ($col,$base) = (getColors($color),getColorsbyName('base'));
	my $colstring = substr($string,0,1) . $col . substr($string,1,1) . $base . substr($string,2);
	return $colstring;
}
print ".";

print " OK; ";
1;
