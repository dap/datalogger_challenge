#!/usr/bin/perl

use Modern::Perl;
use Data::Dumper qw/Dumper/;

my $record_size = 20;

unless ( $ARGV[0] ) {
	say 'Error: no data file supplied';
	exit(1);
}
	
open( my $fh, '<', $ARGV[0] );

my @records;

OUTER: while ( 1 ) {
	my @record;
	
	for (my $i = 0; $i < $record_size; $i++) {
		my $byte;
		read $fh, $byte, 1;
		last OUTER if !$byte;
		push @record, $byte;
	}

	print STDERR Dumper(\@record);
	push @records, \@record;
	next OUTER;
}

close( $fh );

print STDERR Dumper(\@records);
