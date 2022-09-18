# Ideas
# csa - call sub and args combined
# r should behave like m - so r 100 should resolve to return 100;
# mr - combine my and return e.g. mr res [] will create my $res = [] at the
# top of the sub and put return $res; at the bottom
# Then we can do:
# csamr - call sub and args combined then add my and res 
# f item items -> resolves to for my $item (@$items) {
# fa item items -> resolves to my ($items) = @_; then for my $item (@$items)
# sfa get_items item items -> resolves to sub get_items { my ($items) = @_; for my $item (@$items) }
# etc

use strict;
use Test::More;

sub replace_c {
	my ($cargs) = @_;
	
	# e.g. $args = 'subname arg'
	my @args = split /\s+/, $cargs;
	my $subname = shift @args;
	
	my $line = $subname.'(';
	my $arglist = '';
	
	for my $arg (@args) {
		if (length($arglist) > 0) {
			$arglist .= ', ';
		}
		
		$arglist .= '$'.$arg;
	}
	
	$line .= $arglist.');';
	
	return $line;
}

sub replace_relational {
	my ($expr) = @_;
	
	my $op = ($expr =~ />/) ? '>' : '<';
	my @parts = split / $op /, $expr;
	my $rhs = $parts[1];
	
	if ($rhs =~ /[a-zA-Z]/) {
		$rhs = '$'.$rhs;
	}
	
	return "if (\$$parts[0] $op $rhs) {";
}

sub replace_no_op {
	my ($expr) = @_;
	
	my @parts = split / /, $expr;
	
	return "if (\$$parts[0] eq '$parts[1]') {";
}

sub replace_ne {
	my ($expr) = @_;
	
	my @parts = split / ne /, $expr;
	
	return "if (\$$parts[0] ne '$parts[1]') {";
}

sub replace_i {
	my ($expr) = @_;
	
	my $line;
	
	if ($expr =~ />|</) {
		$line = replace_relational($expr);
	}
	else {
		if ($expr =~ / ne /) {
			$line = replace_ne($expr);
		}
		else {
			$line = replace_no_op($expr);
		}
	}
	
	return $line;
}

sub replace_m {
	my ($expr) = @_;
	
	my @parts = split / /, $expr;
	
	my $rhs = $parts[1];
	
	if ($rhs =~ /[a-zA-Z]/) {
		# 'm var1 val1' => 'my $var1 = \'val1\';'
		return "my \$$parts[0] = '$rhs';";
	}
	
	# 'm var1 10' => 'my $var1 = 10;'
	return "my \$$parts[0] = $rhs;";
}

sub remove_indent {
	my ($line) = @_;
	
	my $ind = '';
	
	while ($line =~ /^(\s+)/) {
		$ind = $1;
		$line =~ s/^(\s+)//g;
	}
	
	return ($line, $ind);
}

# Do single line replacements - these only impact
# the line on which the command is done
sub replace_singles {
	my ($bef) = @_;
	
	my $aft = [];
	my $had_action = 0;
	
	for my $orig_line (@$bef) {
		my $ind;
		my $line = $orig_line;
		($line, $ind) = remove_indent($line);
		
		if ($line =~ /^p (.*)/) {
			my $expr = $1;
			
			$line = "print \"$expr\\n\";";
			$had_action = 1;
		}
		
		if ($line =~ /^a (.*)/) {
			my $arg = join ', $', split /\s+/, $1;
			
			$line = 'my ($'.$arg.') = @_;';
			$had_action = 1;
		}
		
		if ($line =~ /^i (.*)/) {
			my $expr = $1;
			
			$line = replace_i($expr);
			$had_action = 1;
		}
		
		if ($line =~ /^r (.*)/) {
			my $expr = $1;
			
			$line = "return \$$expr;";
			$had_action = 1;
		}
		
		if ($line =~ /^m (.*)/) {
			my $expr = $1;
			
			$line = replace_m($expr);
			$had_action = 1;
		}
		
		if ($line =~ /^c (.*)/) {
			my $cargs = $1;
			$line = replace_c($cargs);
			$had_action = 1;
		}
		
		push @$aft, $ind.$line;
	}
	
	if (not $had_action) {
		return undef;
	}
	
	return $aft;
}

sub test_replace_singles {
	my $bef = [
		'p hello',
		'a val1 val2',
		'i x > y',
		'i x > 10',
		'i x str',
		'i x ne str',
		'r val',
		'm var1 val1',
		'm var1 10',
		"\t".'m var1 10',
		"\t\t".'m var1 10',
		'c subname var',
		"\tc subname var",
	];
	
	my $exp = [
		'print "hello\n";',
		'my ($val1, $val2) = @_;',
		'if ($x > $y) {',
		'if ($x > 10) {',
		'if ($x eq \'str\') {',
		'if ($x ne \'str\') {',
		'return $val;',
		'my $var1 = \'val1\';',
		'my $var1 = 10;',
		"\t".'my $var1 = 10;',
		"\t\t".'my $var1 = 10;',
		'subname($var);',
		"\t".'subname($var);',
	];
	
	is_deeply(replace_singles($bef), $exp, 'test_replace_singles');
}

sub get_args_line {
	my ($args) = @_;
	
	my $arg = join ', $', split /\s+/, $args;
	my $line = 'my ($'.$arg.') = @_;';
	
	return $line;
}

sub replace_s {
	my ($bef) = @_;
	
	my $aft = [];
	my $in_sub = 0;
	my $had_action = 0;
	my $sub_lines = [];
	
	for my $line (@$bef) {
		
		if ($line =~ /^\S/) {
			if ($in_sub) {
				while (@$sub_lines and $sub_lines->[-1] =~ /^\s*$/) {
					pop @$sub_lines;
				}
				
				for my $sub_line (@$sub_lines) {
					push @$aft, $sub_line;
				}
				
				push @$aft, '}';
				push @$aft, '';
				
				$in_sub = 0;
			}
		}
		
		if ($line =~ /^s(a?) (\S+)( (.*))?/) {
			print ("Actioning $line\n");
			my $add_args = $1;
			my $subname = $2;
			my $args_str = $4;
			
			$line = "sub $subname {";
			push @$sub_lines, $line;
			
			if ($add_args eq 'a') {
				my $args_line = get_args_line($args_str);
				$args_line = "\t".$args_line;
				
				push @$sub_lines, $args_line;
			}
			
			$in_sub = 1;
			$had_action = 1;
		}
		else {
			if ($in_sub) {
				push @$sub_lines, $line;
			}
			else {
				push @$aft, $line;
			}
		}
	}
	
	if (not $had_action) {
		return undef;
	}
	
	return $aft;
}

sub test_replace_s {
	my $bef = [
		's subname',
		'	somecode',
		'',
		'sub nextsub {',
		'}',
	];
	
	my $exp = [
		'sub subname {',
		'	somecode',
		'}',
		'',
		'sub nextsub {',
		'}',
	];
	
	is_deeply(replace_s($bef), $exp, 'test_replace_s');
}

sub test_replace_sa {
	my $bef = [
		'sa subname arg',
		'	somecode',
		'',
		'sub nextsub {',
		'}',
	];
	
	my $exp = [
		'sub subname {',
		'	my ($arg) = @_;',
		'	somecode',
		'}',
		'',
		'sub nextsub {',
		'}',
	];
	
	my $replaced = replace_s($bef);
	use Data::Dumper;
	print Dumper $replaced;
	is_deeply($replaced, $exp, 'test_replace_sa');
}

sub backup_file {
	my ($file, $lines) = @_;
	
	mkdir "C:\\kungfuperl";
	my $orig_backup_file = "C:\\kungfuperl\\$file";
	my $idx = 1;
	my $backup_file = $orig_backup_file;
	
	while (-e $backup_file) {
		$backup_file = $orig_backup_file.'_'.$idx;
		$idx++;
	}
	
	open BACK_FILE, ">$backup_file" or die "Could not open $backup_file for writing\n";
	
	for my $line (@$lines) {
		print BACK_FILE $line."\n";
	}
	
	close BACK_FILE;
}

sub write_replaced_file {
	my ($file, $replaced) = @_;
	
	open REP_FILE, ">$file" or die "Cannot write to $file\n";
	
	for my $line (@$replaced) {
		print REP_FILE $line."\n";
	}
	
	close REP_FILE;
}

sub action_any_commands() {
	my $file = $ARGV[0];
	
	if (not $file) {
		die "Usage $0 <sourcefile>";
	}
	
	my $prev_mtime = 0;
	my ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime,
	   $ctime, $blksize, $blocks) = stat($file);

	if ($mtime > $prev_mtime) {
		open FILE, "$file" or die "Cannot find $file\n";
		my $lines = [];
		
		while (my $line = <FILE>) {
			chomp $line;
			push @$lines, $line;
		}
		
		close FILE;
		
		my $replaced = replace_s($lines);

		my $replaced_singles;
		
		if (not $replaced) {
			$replaced = $lines;
		}
		
		$replaced_singles = replace_singles($replaced);			
		
		if (not $replaced_singles) {
			$replaced_singles = $replaced;
		}

		if ($replaced_singles != $lines) {
			backup_file($file, $lines);
			write_replaced_file($file, $replaced_singles);
		}
	}
}

sub run {
	if (grep /--once/, @ARGV) {
		action_any_commands();
		exit;
	}
	
	while (1) {
		print("Looking for commands...");
		action_any_commands();
		sleep(1);
	}
}

run();

test_replace_s();
test_replace_sa();
test_replace_singles();

done_testing;

1;

