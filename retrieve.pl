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

	my %options;

	GetOptions(
		'device=s' => \( $options{'device'} ),
		'banner'   => \( $options{'banner'} ),
		'output=s' => \( $options{'output'} ),
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

	tie my $spinner, 'Tie::Cycle', [map {("\b$_")x 5} qw(\ | / -)];

	my $response_buffer = '';

	# 16-bit unsigned integer can hold 2^16 = 65536 different
	# values, it's range being 0 to 65535.
	foreach my $address ( 0 .. (2**16 - 1) ) {
		$address = pack('n', $address);

		$port->write( ">r$address\n" );

		my ( $num_bytes_read, $bytes_read);
		my $num_bytes_to_read = 3;
		my $response_read;

		while ( $num_bytes_to_read > length($response_buffer) ) {
			($num_bytes_read, $bytes_read)
				= $port->read($num_bytes_to_read);

			$response_buffer .= $bytes_read;
		}

		print STDERR $spinner;
		$response_read = substr($response_buffer, 0, 3, '');

		if ( 'r1' eq substr($response_read, 0, 2) && $response_read ne "r1\0" ) {
			print STDERR "\b..";
			$response_read =~ m/r1(.*)/;
			print $out $1;
			$found++;
		}

	}

	say "\nSaved $found bytes.";
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

	if ($output eq '-')
	{
		return \*STDOUT;
	}

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
