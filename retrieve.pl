#!/usr/bin/perl

use Modern::Perl;
use Getopt::Long;
use File::Basename;
use Term::ReadLine;
use Device::SerialPort;
use Tie::Cycle;

$| = 1;

main() if $0 eq __FILE__;

sub main {

	my %options = (
		'endianness' => 'little',
	);

	GetOptions(
		'banner'        => \( $options{'banner'}        ),
		'device=s'      => \( $options{'device'}        ),
		'endianness=s'  => \( $options{'endianness'}    ),
		'output=s'      => \( $options{'output'}        ),
	);

	my $dev = verify_specified_device  ( $options{'device'} );
	my $out = verify_output_destination( $options{'output'} );

	my $port = Device::SerialPort->new($dev, 0);

	$port->baudrate( 9600   );
	$port->parity  ( 'none' );
	$port->databits( 8      );
	$port->stopbits( 1      );

	if ( $options{'banner'} ) {
		wait_and_display_banner($port);
	}

	my $found = 0;

	my $read_pack_format
		= $options{'endianness'} eq 'little'
		? 'v'
		: 'n';

	tie my $spinner, 'Tie::Cycle', [map {("\b$_")x 5} qw(\ | / -)];

	# 16-bit unsigned integer can hold 2^16 = 65536 different
	# values, it's range being 0 to 65535.
	foreach my $address ( 0 .. (2**16 - 1) ) {

		$address = pack($read_pack_format, $address);

		$port->write( ">r$address\n" );

		my $total_bytes_read = 0;
		my $num_bytes_read   = 0;
		my $bytes_read;

		while ($total_bytes_read != 3 ) {
			($num_bytes_read, $bytes_read)
				= $port->read(1);
			$total_bytes_read += $num_bytes_read;
		}

		print STDERR $spinner;

		syswrite $out, $bytes_read;
		$bytes_read = 0;
		$found++;
	}

	say STDERR "\nSaved $found bytes.";
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

	say STDERR $banner;
}

sub verify_specified_device {
	my $device = shift;

	my $error = sub { say STDERR $_[0]; exit(1) };

	if ( !$device || $device !~ m/^\/dev/g ) {
		$error->('Error: No serial device specified.');
	}

	if ( ! -e $device ) {
		$error->('Error: Specified device does not exist.');
	}

	if ( ! -r $device ) {
		$error->('Error: Specified device is not readable.');
	}

	if ( ! -w $device ) {
		$error->('Error: Specified device is not writable.');
	}

	return $device;
}

sub verify_output_destination {
	my $output = shift;

	my $error = sub { say STDERR $_[0]; exit(1) };

	if ( !$output ) {
		$error->('Error: No output path specified.');
	}

	if ( -e $output ) {
		my $term = Term::ReadLine->new($0);
		$term->ornaments(0);
		my $overwrite = '';

		while ($overwrite ne 'y' && $overwrite ne 'n') {
			$overwrite = $term->readline('Error: Specified output path already exists. Overwrite (y/n)?');
			say $overwrite;
		}
		$error->('Aborted.')
			if $overwrite eq 'n';
	}

	my ($filename, $directory) = fileparse($output);

	if ( ! -w $directory ) {
		$error->("Error: cannot write to $directory");
	}

	open(my $fh, '>', $output);

	return $fh;
}
