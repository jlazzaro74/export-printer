#!/usr/bin/perl
#
#	(cL) 2014 Joseph Lazzaro jlazzaro2@uh.edu
#
#	Read the full configuration of a locally installed printer and generate
#	a shell script that can be run to add the printer, exactly as configured,
#	on another system. The printer driver must, of course, already be installed.
#
# =============================================================================

use strict;
use Data::Dumper;
use Text::ParseWords;

my $printer_name = $ARGV[0] || die "Specify a printer queue name to export its options\n"; # Queue name to be duplicated
my $script_file  = $ARGV[1] || "./" . $printer_name . "_options.sh"; # Name of shell script to be saved, defaults to printer name

if (-e $script_file) {
	print "The output file already exists and will be overwritten. Are you sure you want to continue? [y/N]";
	my $response = <STDIN>;
	if ($response !~ /^y/i) {
		exit(0);
	}
}

# Fetch the maximum length a command line argument can be to make sure we don't build an lpadmin command that can't be run
my $max_line_length = `getconf ARG_MAX`;

my $SCRIPTFILE = ''; # The big string that gets written to the output file

#
#	Get the device settings without -l for the device-uri, shared status, etc
#
my $options_text = `lpoptions -p "$printer_name"`;

if ($options_text !~ /device-uri/) {
	die "The printer queue does not exist\n";
}

# Parse the results of lpoptions -p "blah" and save the option names and values in an assoc array
my $printer = { map { m|(.+)=(.+)|; $1 => $2 } quotewords(' ', 0, $options_text) };

# Locate the printer PPD file for the printer model by using lpinfo
my $ppd = ''; # A path to a PPD file
my $ppd_info = `lpinfo --make-and-model "$printer->{'printer-make-and-model'}" -m 2> /dev/null`;

# The PPD file will be returned at the beginning of the line and should end with .gz
# If for some reason lpinfo returned multiple PPDs this would just pick the first one, but I haven't seen that happen yet.
if ($ppd_info =~ m|^(.*?\.gz)|) {
	$ppd = $1;
	
	# Make sure the PPD path begins with a /, lpinfo returns without it
	if ($ppd !~ m|^/|) {
		$ppd = "/" . $ppd;
	}
} else {
	die "Cannot locate ppd file for printer model '$printer->{'printer-make-and-model'}'\n";
}

# Begin constructing the lpadmin command
$SCRIPTFILE = qq{lpadmin -p "$printer_name" -L "$printer->{'printer-location'}" -D "$printer->{'printer-info'}" -v "$printer->{'device-uri'}" -P "$ppd" -o printer-is-shared=$printer->{'printer-is-shared'} -o printer-error-policy=abort-job -E};

#
#	Get the long lpoptions for device settings
#
$options_text = `lpoptions -p "$printer_name" -l 2> /dev/null`;

foreach (split("\n", $options_text)) {
	m|^(.+?)/.+\:.+\*(\S+)|;
	next if (!length $1 or !length $2);
	$SCRIPTFILE .= qq{ -o $1=$2};
}

# Make sure the length of our arguments don't exceed the system's maximum shell argument length
if (length $SCRIPTFILE >= $max_line_length) {
	die "Resulting command was too long for your system's maximum shell argument, aborting\n";
}

# Save the command to a file
open(SCRIPTFILE, ">$script_file") || die "Can't open script file $script_file for write\n";
print SCRIPTFILE "#!/bin/sh\n";
print SCRIPTFILE "$SCRIPTFILE\n";
close(SCRIPTFILE);

exit(0);
