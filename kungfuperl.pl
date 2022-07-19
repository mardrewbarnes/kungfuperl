
use Test::More;

sub replace_s {
	my ($bef) = @_;
	
	my $aft = [];
	my $is_sub = 0;
	my $had_action = 0;
	my $sub_lines = [];
	
	for my $line (@$bef) {
		
		if ($line =~ /^\S/) {
			if ($in_sub) {
				while ($sub_lines->[-1] =~ /^\s*$/) {
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
		
		if ($line =~ /^s (.*)/) {
			print ("Actioning $line\n");
			my $subname = $1;
			$line = "sub $subname {";
			$in_sub = 1;
			$had_action = 1;
		}

		if ($in_sub) {
			push @$sub_lines, $line;
		}
		else {
			push @$aft, $line;
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
		'sub nextsub() {',
		'}',
	];
	
	my $exp = [
		'sub subname() {',
		'	somecode',
		'}',
		'',
		'sub nextsub() {',
		'}',
	];
	
	is_deeply(replace_s($bef), $exp, 'test_replace_s');
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
		
		if ($replaced) {
			backup_file($file, $lines);
			write_replaced_file($file, $replaced);
		}
	}
}

while (1) {
	print("Looking for commands...");
	action_any_commands();
	sleep(1);
}

#test_replace_s();

#done_testing;

1;


