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

sub DoBrangefromAges {
	my ($n,$x,$inclusive) = @_;
	use DateTime;
	return undef unless (defined $n and $n ne '');
	$n = int($n);
	$x = int($n) unless defined $x;
	$x = int($x);
	$inclusive = 0 unless defined $inclusive;
	my ($xs,$ns) = (DateTime->now,DateTime->now);
	$xs->subtract(years => $n, days => -$inclusive);
	$ns->subtract(years => $x, days => 364 + $inclusive);
	return $xs->ymd('-'),$ns->ymd('-'); # DoB should be < 1 and > 2
}
print ".";

my %errorcodelist;
sub registerErrors {
	my ($func,@errors) = @_;
	$errorcodelist{$func} = ["[I] 0",@errors];
	if (1) {
		print "- Registering error codes for $func:\n";
		foreach (0 .. $#errors) {
			print "\t" . $_ + 1 . ": $errors[$_]\n";
		}
	}
use Data::Dumper;
print Dumper %errorcodelist;
}
print ".";

sub errorOut {
	my ($func,$code,$fatal,$color) = @_;
	unless (defined $func and defined $code) {
		warn "errorOur called without required parameters";
		return 1;
	}
	unless (defined $fatal and defined $color) {
		use FIO qw( config ); # TODO: Fail gracefully here (eval?)
		$fatal = ( FIO::config('Main','fatalerr') or 0 ) unless defined $fatal;
		$color = ( FIO::config('Debug','termcolors') or 1 ) unless defined $color;
	}
	my $error = "errorOut could not find error code $code associated with $func";
	unless (defined $errorcodelist{$func}) {
		warn $error;
		return 2;
	}
	my @list = @{ $errorcodelist{$func} };
	unless (int($code) < scalar @list) {
		# TODO: Test for %d in final error code. If found, use it with generic error message.
#		$code = $#list;
		# } else {
		warn $error;
		return 2;
		# }
	}
	# actually regirstered error codes:
	$error = $list[int($code)];
	if ($error =~ m/^\[E\]/) { # error
		$color = ($color ? 1 : 0);
		($fatal ? die errColor($error,$color) . " in $func\n" : warn errColor($error,$color) . " in $func\n");
	} elsif ($error =~ m/^\[W\]/) { # warning
		$color = ($color ? 3 : 0);
		($fatal ? warn errColor($error,$color) . " in $func\n" : print errColor($error,$color) . " in $func\n");
	} elsif ($error =~ m/^\[I\]/) { # information
		$color = ($color ? 2 : 0);
		print errColor($error,$color) . " in $func\n";
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
