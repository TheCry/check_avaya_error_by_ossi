#!/usr/bin/perl
=pod

=head1 COPYRIGHT

This software is Copyright (c) 2013 by Sascha Bay

=head1 LICENSE

This work is made available to you under the terms of Version 2 of
the GNU General Public License.

=head1 NAME

check_avaya_error_by_ossi.pl

=head1 SYNOPSIS

Checks AVAYA S8xx components for callmanager- or serverfailures using OSSI protocol.
You need to create a station file (pbx_connection_auth.xml) to the folder /usr/local/nagios/etc/avaya/ (Default)
<pbx-systems>
        <pbx name='n1' hostname='xxx.xxx.xxx.xxx' port='22' login='username'  password='password' connection_type='ssh' atdt='' />
</pbx-systems>

=head1 OPTIONS

check_avaya_error_by_ossi.pl -H <hostname> -S <LISU|CML> -L <MAJOR|MINOR|WARNING|ALL>

=over

=item   B<-H (--hostname)>

Hostname to query in the file pbx_connection_auth.xml - (required)

=item   B<-S (--service)>

LISU - List Survival, CML - Communicationmanagerlog - (required)

=item   B<-L (--errorlevel)>

MAJOR, MINOR, WARNING, ALL (only -S = CML)

=item   B<-i (--ignore)>

ignores Maintnames (only -S = CML), Array possible (Name,Name,Name)

=item   B<-a (--alarmport)>

ignores Alarmports (only -S = CML), Array possible (Name,Name,Name)

=item   B<-M (--changemajor)>

changes the status to major (only -S = CML), Array possible (Name,Name,Name)

=item   B<-SL (--lspserverlist)>

An integer which let us know wheter the plugin should use a serverlist with active servers for LISU (1=TRUE, 0=FALSE)
Then use the File LSPServer.pm (folder /usr/local/nagios/etc/avaya/) to add the active server in an array (only -S = LISU)

=item   B<-V (--version)>

Plugin version

=back

=head1 DESCRIPTION

Checks AVAYA S8xx components for callmanager- or serverfailures using OSSI protocol.

=cut

use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use lib '/usr/local/nagios/libexec/';
use utils qw(%ERRORS);
require "DEFINITY_ossi.pm";
import DEFINITY_ossi;

sub nagiosplugexit($$);
sub print_version ();
sub writelogfile($$);

########### Variablen setzen ##############
my ($AlarmLevel, $PBXAlarmLevel, @IGNORE_MAINTNAME, @IGNORE_ALARMPORT, @CHANGE_STATUS_2_MAJOR);
my ($ServerName, $ServerIP, $LSPDateTime, $LSPType, $SurvivalReg, $SurvivalAct);
my ($Survival_Updated_Time, $Survival_Updated_Date);
my $version = undef;
my $help = undef;
my $hostname = undef;
my $service = undef;
my $errorlevel = undef;
my $ignore_maintname = undef;
my $ignore_alarmport = undef;
my $changemajor = undef;
my $lspserverlist = undef;
my $checklspserverlist = 0;
my $value = undef;
my $AlarmLevelBeforeChange2Major = '';
my $numberErrors = 0;
my $WRNErrors = 0;
my $MINErrors = 0;
my $MAJErrors = 0;
my $continue_record = 0;
my $output = '';
my $exitcode = -1;

my $PBX_CONFIG_FILE_PATH = '';
my $DEGBUGLOGFILE = '/usr/local/nagios/var/avaya_debug_errors.log';


my $DEBUG = 0;
my $DEGUBBINGTOLOG = 0;

############################################

my $VERSION = "1.0.1";
my $AUTHOR = "Sascha Bay";

my %statusCodes = (	1			=> "OK",
					2			=> "WARNING",
					3			=> "CRITICAL",
					4			=> "UNKNOWN",
					"WARNING"	=> 1,
					"CRITICAL"	=> 2,
					"MINOR"		=> 2,
					"MAJOR"		=> 2);
					
my %errorColors = (	"WARNING"	=> "#FFFF00",
					"CRITICAL"	=> "#F83838",
					"UNKNOWN"	=> "#FF9900");

# check the command line options
GetOptions(
		'help|?'				=>	\$help,
		'V|version'				=>	\$version,
		'H|hostname=s'			=>	\$hostname,
		'S|service=s'			=>	\$service,
		'L|errorlevel=s'		=>	\$errorlevel,
		'i|ignoremaintname=s'	=>	\$ignore_maintname,
		'a|ignorealarmport=s'	=>	\$ignore_alarmport,
		'M|changemajor=s'		=>	\$changemajor,
		'SL|lspserverlist=i'	=>	\$lspserverlist
		);

print_version () if $version;

if (!defined $hostname || !defined $service || !defined $errorlevel && $service eq "CML") {$help=1;} # wrong number of command line options
if (!defined $hostname) {$help=1;}
pod2usage(1) if $help;

################ Check that all parameters given ###################

# Unknown Parameter for service
if ($service !~ /LISU/ && $service !~ /CML/) 
{
	writelogfile('UNKNOWN', "Unknown Parameter for [service]. Please specify LISU | CML") if $DEGUBBINGTOLOG;
	nagiosplugexit('UNKNOWN', "Unknown Parameter for [service]. Please specify LISU | CML");
}
# Unknown Parameter for Errorlevel
if($service !~ /LISU/) 
{
	if ($errorlevel !~ /MAJOR/ && $errorlevel !~ /MINOR/ && $errorlevel !~ /WARNING/ && $errorlevel !~ /ALL/) 
	{
		writelogfile('UNKNOWN', "Missing argument [errorlevel]. Please specify MAJOR | MINOR | WARNING | ALL") if $DEGUBBINGTOLOG;
		nagiosplugexit('UNKNOWN', "Unknown Parameter for [errorlevel]. Please specify MAJOR | MINOR | WARNING | ALL");
	}
}

if(defined $lspserverlist && $lspserverlist == 1) 
{
	$checklspserverlist = $lspserverlist;
	use lib '/usr/local/nagios/etc/avaya/';
	use LSPServer qw(@LSP_ACTIVE_SERVER);
}

############################ Subroutines ###########################

sub print_version () 
{
	nagiosplugexit('OK', "Version: $VERSION, Copyright (c) 2013 $AUTHOR\n");
}
sub writelogfile($$) 
{
	my $errorlevel = shift;
	my $messagestring = shift;
	open(DEGBUGLOGFILE, ">> $DEGBUGLOGFILE");
	print(DEGBUGLOGFILE "$errorlevel: $messagestring\n");
	close(DEGBUGLOGFILE);
}
sub nagiosplugexit($$) 
{
	my $errorlevel = shift;
	my $messagestring = shift;
	print "$errorlevel: $messagestring\n";
	exit $ERRORS{$errorlevel};
}

####################################################################

my $node = new DEFINITY_ossi($hostname, $DEBUG, $PBX_CONFIG_FILE_PATH);
unless($node && $node->status_connection())
{
	writelogfile('CRITICAL', "ERROR: Login failed for ". $hostname) if $DEGUBBINGTOLOG;
	nagiosplugexit('CRITICAL', "ERROR: Login failed for ". $hostname);
}

if ($service eq "LISU") 
{
	$node->pbx_command("li surv");
	
	writelogfile('OK', "Send command 'li surv'.") if $DEGUBBINGTOLOG;
	
	if ($node->last_command_succeeded()) 
	{
		my @ossi_output = $node->get_ossi_objects();
		
		writelogfile('OK', "Listsurvival Output: ". Dumper(@ossi_output)) if $DEGUBBINGTOLOG;
		print Dumper(@ossi_output) if $DEBUG;
		
		foreach my $hash_ref(@ossi_output) 
		{
			for my $field ( sort keys %$hash_ref ) 
			{
				if(defined $hash_ref->{$field})
				{
					$value = $hash_ref->{$field};
				} else {
					$value = 'NA';
				}
				
				$ServerName = $value if ($field eq '7400ff00');
				$ServerIP = $value if ($field eq '7401ff00');
				$LSPDateTime = $value if ($field eq '7403ff00');
				$LSPType = $value if ($field eq '7405ff00');
				$SurvivalReg = $value if ($field eq '7407ff00');
				$SurvivalAct = $value if ($field eq '7408ff00');
					
				print "\t$field => $value\n" if $DEBUG;
			}
			
			if($checklspserverlist == 1)
			{
				if (grep $_ eq $ServerName, @LSP_ACTIVE_SERVER)
				{
					if($SurvivalReg eq "n" or $SurvivalAct eq "y")
					{
						if($LSPDateTime eq 'NA' || $LSPDateTime eq '')
						{
							$Survival_Updated_Time = 'NA';
							$Survival_Updated_Date = 'NA';
						} else {
							($Survival_Updated_Time, $Survival_Updated_Date) = split(/ /, $LSPDateTime);
						}
						$AlarmLevel = "CRITICAL";
						
						writelogfile($AlarmLevel, "Alarm - Reg: ".$SurvivalReg." - Act: ".$SurvivalAct.", ".$ServerName." (IP: ".$ServerIP."), Type: ".$LSPType.", Translations Updated: ".$Survival_Updated_Date." - ".$Survival_Updated_Time." Uhr") if $DEGUBBINGTOLOG;
						
						$output .= "<span style='background-color:".$errorColors{$AlarmLevel}."'>[".($numberErrors+1)."]</span> - Alarm - Reg: ".$SurvivalReg." - Act: ".$SurvivalAct.", ".$ServerName." (IP: ".$ServerIP."), Type: ".$LSPType.", Translations Updated: ".$Survival_Updated_Date." - ".$Survival_Updated_Time." Uhr<br />";
						$exitcode = $statusCodes{$AlarmLevel};
						$numberErrors++;
					}
				}
			} else {
				if($LSPDateTime eq 'NA' || $LSPDateTime eq '')
				{
					if($LSPDateTime eq 'NA')
					{
						$Survival_Updated_Time = 'NA';
						$Survival_Updated_Date = 'NA';
					} else {
						($Survival_Updated_Time, $Survival_Updated_Date) = split(/ /, $LSPDateTime);
					}
					$AlarmLevel = "CRITICAL";
					
					writelogfile($AlarmLevel, "Alarm - Reg: ".$SurvivalReg." - Act: ".$SurvivalAct.", ".$ServerName." (IP: ".$ServerIP."), Type: ".$LSPType.", Translations Updated: ".$Survival_Updated_Date." - ".$Survival_Updated_Time." Uhr") if $DEGUBBINGTOLOG;
					
					$output .= "<span style='background-color:".$errorColors{$AlarmLevel}."'>[".($numberErrors+1)."]</span> - Alarm - Reg: ".$SurvivalReg." - Act: ".$SurvivalAct.", ".$ServerName." (IP: ".$ServerIP."), Type: ".$LSPType.", Translations Updated: ".$Survival_Updated_Date." - ".$Survival_Updated_Time." Uhr<br />";
					$exitcode = $statusCodes{$AlarmLevel};
					$numberErrors++;
				}
			}
		}
	} else {
		writelogfile('CRITICAL', "Command 'li surv' returns an error.") if $DEGUBBINGTOLOG;
		nagiosplugexit('CRITICAL', "Command 'li surv' returns an error.");
	}
}
if ($service eq "CML") 
{
	################## Parse extra parameters ##########################

	if (defined $ignore_maintname) 
	{
		if(grep /,/ , $ignore_maintname)
		{
			writelogfile('OK', "Ignore Maintname: ". $ignore_maintname) if $DEGUBBINGTOLOG;
			@IGNORE_MAINTNAME = split(/,/, $ignore_maintname);
		} else {
			writelogfile('OK', "Ignore Maintname: ". $ignore_maintname) if $DEGUBBINGTOLOG;
			push(@IGNORE_MAINTNAME,$ignore_maintname);
		}
	}

	if (defined $ignore_alarmport) 
	{
		if(grep /,/ , $ignore_alarmport)
		{
			writelogfile('OK', "Ignore Alarmport: ". $ignore_alarmport) if $DEGUBBINGTOLOG;
			@IGNORE_ALARMPORT = split(/,/, $ignore_alarmport);
		} else {
			writelogfile('OK', "Ignore Alarmport: ". $ignore_alarmport) if $DEGUBBINGTOLOG;
			push(@IGNORE_ALARMPORT,$ignore_alarmport);
		}
	}

	if (defined $changemajor) 
	{
		if(grep /,/ , $changemajor)
		{
			writelogfile('OK', "Change Mainname to Major: ". $changemajor) if $DEGUBBINGTOLOG;
			@CHANGE_STATUS_2_MAJOR = split(/,/, $changemajor);
		} else {
			writelogfile('OK', "Change Mainname to Major: ". $changemajor) if $DEGUBBINGTOLOG;
			push(@CHANGE_STATUS_2_MAJOR,$changemajor);
		}
	}
	#####################################################################
	
	$node->pbx_command("display alarms");
	
	writelogfile('OK', "Send command 'display alarms'.") if $DEGUBBINGTOLOG;
	
	if ($node->last_command_succeeded()) 
	{
		my @ossi_output = $node->get_ossi_objects();
		
		writelogfile('OK', "List Display Alarms Output: ". Dumper(@ossi_output)) if $DEGUBBINGTOLOG;
		print Dumper(@ossi_output) if $DEBUG;
		
		# Alarmport, Maintname, AltName, AlarmType, Day, Month, Hour, Minute
		my @NEEDED_OUTPUT_FIELDS = ('0001ff00', '0002ff00', '0004ff00', '0005ff00', '0006ff00', '000eff00', '0007ff00', '0008ff00');
		foreach my $hash_ref(@ossi_output) 
		{
			my ($AlarmDay, $AlarmMonth, $AlarmHour, $AlarmMinute);
			my $Alarmport = undef;
			my $MaintName = undef;
			my $AltName = undef;
			my $Alarmdate = undef;
			my $Alarmtime = undef;

			for my $field ( sort keys %$hash_ref ) 
			{
				if(defined $hash_ref->{$field})
				{
					$value = $hash_ref->{$field};
				} else {
					$value = 'NA';
				}
				if (grep $_ eq $field, @NEEDED_OUTPUT_FIELDS)
				{
					$Alarmport = $value if ($field eq '0001ff00');
					$MaintName = $value if ($field eq '0002ff00');
					$AltName = $value if ($field eq '0004ff00');
					$AlarmLevel = $value if ($field eq '0005ff00');
					
					$AlarmDay = $value if ($field eq '0006ff00');
					$AlarmMonth = $value if ($field eq '000eff00');
					$AlarmHour = $value if ($field eq '0007ff00');
					$AlarmMinute = $value if ($field eq '0008ff00');				
				}
				
				print "\t$field => $value\n" if $DEBUG;
			}
			
			$Alarmdate = $AlarmDay .".".$AlarmMonth;
			$Alarmtime = $AlarmHour.":".$AlarmMinute;
			
			if(defined $changemajor && grep $_ eq $MaintName, @CHANGE_STATUS_2_MAJOR)
			{
				$AlarmLevelBeforeChange2Major = ' <strong>[pushed to MAJOR, received from server alarm: '.$AlarmLevel.']</strong> ';
				$AlarmLevel = "MAJOR";
			} else {
				$AlarmLevelBeforeChange2Major = '';
			}
			
			if($AlarmLevel eq $errorlevel || $errorlevel eq 'ALL' && $AlarmLevel ne 'NA')
			{
				$continue_record = 0;
				
				if(defined $ignore_maintname && grep $_ eq $MaintName, @IGNORE_MAINTNAME) 
				{
					$continue_record = 1;
				}
				if(defined $ignore_alarmport && grep $_ eq $Alarmport, @IGNORE_ALARMPORT) 
				{
					$continue_record = 1;
				}
				if($continue_record eq 0) 
				{
					$PBXAlarmLevel = $AlarmLevel;
					if($AlarmLevel eq "WARNING") {$AlarmLevel = "WARNING";$WRNErrors++;}
					elsif($AlarmLevel eq "MINOR") {$AlarmLevel = "CRITICAL";$MINErrors++;}
					elsif($AlarmLevel eq "MAJOR") {$AlarmLevel = "CRITICAL";$MAJErrors++;}
					
					writelogfile($AlarmLevel, "Output: Alarm(".$PBXAlarmLevel.")".$AlarmLevelBeforeChange2Major." => Alarmport: ".$Alarmport.", MaintName: ".$MaintName.", Date: ".$Alarmdate." - ".$Alarmtime." Uhr") if $DEGUBBINGTOLOG;
					
					$output .= "<span style='background-color:".$errorColors{$AlarmLevel}."'>[".($numberErrors+1)."]</span> - Alarm(".$PBXAlarmLevel.")".$AlarmLevelBeforeChange2Major." => Alarmport: ".$Alarmport.", MaintName: ".$MaintName.", Date: ".$Alarmdate." - ".$Alarmtime." Uhr<br />";
					if ($exitcode lt $statusCodes{$AlarmLevel}) 
					{
						$exitcode = $statusCodes{$AlarmLevel};
					}
					$numberErrors++;
				}
			}
		}
	} else {
		writelogfile('CRITICAL', "Command 'display alarms' returns an error.") if $DEGUBBINGTOLOG;
		nagiosplugexit('CRITICAL', "Command 'display alarms' returns an error.");
	}
	$node->do_logoff();
}

############# Exit script in a nagios friendly way #################

if($numberErrors eq 0 && $service eq "LISU") 
{
	nagiosplugexit('OK', "All Survivals are working.");
}
elsif($numberErrors eq 0 && $service eq "CML") 
{
	$errorlevel = 'WARNING, MINOR, MAJOR' if($errorlevel eq 'ALL');
	nagiosplugexit('OK', "No Communicationmanager-Alarms with level *$errorlevel*.");
} else {
	if($service eq "LISU") 
	{
		nagiosplugexit($statusCodes{$exitcode+1}, "Existing LSP-Alarme: ".$numberErrors."<br />".$output);
	} else {
		nagiosplugexit($statusCodes{$exitcode+1}, "WARNING-Alarms: ".$WRNErrors." - MINOR-Alarms: ".$MINErrors." - MAJOR-Alarms: ".$MAJErrors."<br />".$output) if($errorlevel eq 'ALL');
		nagiosplugexit($statusCodes{$exitcode+1}, "WARNING-Alarms: ".$WRNErrors."<br />".$output) if($errorlevel eq 'WARNING');
		nagiosplugexit($statusCodes{$exitcode+1}, "MINOR-Alarms: ".$MINErrors."<br />".$output) if($errorlevel eq 'MINOR');
		nagiosplugexit($statusCodes{$exitcode+1}, "MAJOR-Alarms: ".$MAJErrors."<br />".$output) if($errorlevel eq 'MAJOR');
	}
}