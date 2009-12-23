#!/usr/bin/perl

use Modern::Perl;
use Getopt::Long;
use Device::SerialPort;
use Time::HiRes qw/usleep/;
use Tie::Cycle;

$| = 1;

main() if $0 eq __FILE__;

sub main {

	my %options;

	GetOptions(
		"banner" => \($options{'banner'}),
	);

	my $dev = verify_specified_device();

	my $port = Device::SerialPort->new($dev, 0);

	$port->baudrate( 9600   );
	$port->parity  ( 'none' );
	$port->databits( 8      );
	$port->stopbits( 1      );

	if ( $options{'banner'} ) {
		wait_and_display_banner($port);
	}

	my @found;

	tie my $spinner, 'Tie::Cycle', [map {("\b$_")x 5} qw(\ | / -)];

	print 'Working:  ';

	# 16-bit unsigned integer can hold 2^16 = 65536 different
	# values, it's range being 0 to 65535.
	foreach my $address ( 0 .. (2**16 - 1) ) {
		$address = pack('n', $address);

		$port->write( ">r$address\n" );

		usleep 50000;
		
		my $data_bytes_read = $port->input();
		print $spinner;

		if ( $data_bytes_read ne "r1\0" ) {
			$data_bytes_read =~ m/r1(.*)/;
			push @found, unpack('a', $1);
		}

	}

	say "\nFound ", scalar(@found) . ' bytes';
	say join('', @found);
}

sub wait_and_display_banner {
	my $port = shift;

	my ( $num_bytes_read, $banner_bytes_read);
	my $num_bytes_to_read = 1;
	my $banner = '';

	while ( $banner !~ m/Go$/ ) {
		($num_bytes_read, $banner_bytes_read)
			= $port->read($num_bytes_to_read);

		$banner .= $banner_bytes_read
			if $num_bytes_read;
	}

	say $banner;
}

sub verify_specified_device {

	my $message = sub { say $_[0]; exit(1) };

	if ( !$ARGV[0] || $ARGV[0] !~ m/^\/dev/g ) {
		$message->('Error: No serial device specified.');
	}

	if ( ! -e $ARGV[0] ) {
		$message->('Error: Specified device does not exist.');
	}

	if ( ! -r $ARGV[0] ) {
		$message->('Error: Specified device does not readable.');
	}

	if ( ! -w $ARGV[0] ) {
		$message->('Error: Specified device does not writable.');
	}

	return $ARGV[0];
}