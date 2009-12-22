#!/usr/bin/perl

use Modern::Perl;
use Device::SerialPort;

my $dev = '/dev/ttyUSB0';

sub main {

	my $port = Device::SerialPort->new($dev, 0);

	$port->baudrate( 9600   );
	$port->parity  ( 'none' );
	$port->databits( 8      );
	$port->stopbits( 1      );

	my ( $num_bytes_read, $bytes_read);
	my $num_bytes_to_read = 1;
	my $banner = '';

	while ( $banner !~ m/Go$/ ) {
		($num_bytes_read, $bytes_read)
			= $port->read($num_bytes_to_read);

		$banner .= $bytes_read
			if $num_bytes_read;
	}

	say $banner;

	$num_bytes_to_read = 3;

	my $read_command_format = '%02x';

	foreach my $address ( 0x00 .. 0xff ) {
		my $read_command = reverse(
			sprintf($read_command_format, $address)
		);
		$read_command = '>r' . $read_command . "\n";
		say $read_command;

		$port->write( $read_command );
		
		($num_bytes_read, $bytes_read)
			= $port->read($num_bytes_to_read);

		say $bytes_read;
	}
}

main() if $0 eq __FILE__;
