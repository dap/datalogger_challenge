#!/usr/bin/perl

use Modern::Perl;
use Device::SerialPort;
use Time::HiRes qw/usleep/;
use Tie::Cycle;

$| = 1;

my $dev = '/dev/ttyUSB0';

sub main {

	my $port = Device::SerialPort->new($dev, 0);

	$port->baudrate( 9600   );
	$port->parity  ( 'none' );
	$port->databits( 8      );
	$port->stopbits( 1      );

	#my ( $num_bytes_read, $banner_bytes_read);
	#my $num_bytes_to_read = 1;
	#my $banner = '';

	#while ( $banner !~ m/Go$/ ) {
	#	($num_bytes_read, $banner_bytes_read)
	#		= $port->read($num_bytes_to_read);

	#	$banner .= $banner_bytes_read
	#		if $num_bytes_read;
	#}

	#say $banner;

	my $data_bytes_read = '';

	#my $read_command_format = '%02x';
	my $read_command_format = '%x';

	my %bytes_found;
	my @found_string;

	tie my $spinner, 'Tie::Cycle', [map {("\b$_")x 5} qw(\ | / -)];

	print 'Working:  ';

	# 16-bit unsigned integer can hold 2^16 = 65536 different
	# values, it's range being 0 to 65535.
	foreach my $address ( 0 .. (2**16 - 1) ) {
		#$address = sprintf($read_command_format, $address);
		$address = pack('n', $address);
		#$address = $address;
		#$address = reverse( $address );
		#$address = chr $address;
		#$address = $address;

		$port->write( ">r$address\n" );

		usleep 50000;
		
		$data_bytes_read = $port->input();
		print $spinner;

		if ( $data_bytes_read ne "r1\0" ) {
			$data_bytes_read =~ m/r1(.*)/;
			push @found_string, unpack('a', $1);
			$bytes_found{$address} = ord $1;
		}

		#say $num_bytes_read, $read_command, $data_bytes_read;
	}

	use Data::Dumper qw/Dumper/;
	#print Dumper(\%bytes_found);
	say "\nFound ", scalar(keys %bytes_found);
	say join('', @found_string);
}

main() if $0 eq __FILE__;
