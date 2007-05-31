#!/usr/bin/perl -w
#-----------------------------------------------------------+
#                                                           |
# PhyInit.pl - Initialize a phyloinformatics database       |
#                                                           |
#-----------------------------------------------------------+
#                                                           |
#  AUTHOR: James C. Estill                                  |
# CONTACT: JamesEstill_at_gmail.com                         |
# STARTED: 05/30/2007                                       |
# UPDATED: 05/31/2007                                       |
#                                                           |
# DESCRIPTION:                                              | 
#  Initialize a BioSQL database with the phyloinformatics   |
#  tables. This will initially only work with MySQL, but    |
#  other databases can be made available. I will also       | 
#  initially assume that BioSQL already exists, and will    |
#  just add the phyloinforamtics tables                     |
#                                                           |
#-----------------------------------------------------------+
#
# THIS SOFTWARE COMES AS IS, WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTY. USE AT YOUR OWN RISK.

# NOTE: Variables from command line follow load_ncbi_taxonomy.pl

=head1 NAME 

PhyInit.pl - Initialize a phyloinformatics database.

=head1 SYNOPSIS

  Usage: PhyInit.pl
        --dsn        # The DSN string the database to connect to
        --dbname     # Name of database to use
        --dbuser     # user name to connect with
        --dbpass     # password to connect with
        --driver     # "mysql", "Pg", "Oracle" (default "mysql")
        --host       # optional: host to connect with
        --help       # Print this help message
        --quiet      # Run the program in quiet mode.
                   
=head1 DESCRIPTION

Initialize a BioSQL database with the phyloinformatics tables. This will
initially only work with MySQL, but other databases can later be made 
available with the driver argument.

=head1 ARGUMENTS

=over

=item -u, --dbuser

The user name to connect to; default is the value in the environment
variable DBI_USER.

This user must have permission to create databases.

=item -p, --dbpass

password to connect with; default is the value in the environment
variable DBI_PASSWORD

=item -d, --dsn

the DSN of the database to connect to; default is the value in the
environment variable DBI_DSN. If DBI_DSN has not been defined and
the string is not passed to the command line, the dsn will be 
constructed from --driver, --dbname, --host

Example: DBI:mysql:database=biosql;host=localhost

=item --host

The database host to connect to; default is localhost.

=item --dbname

The database name to connect to; default is biosql.

=item --driver

The database driver to connect with; default is mysql.
Options other then mysql are currently not supported.
    
=item -h, --help

Print the help message.

=item -q, --quiet

Print the program in quiet mode. No output will be printed to STDOUT
and the user will not be prompted for intput.

=back

=head1 AUTHORS

James C. Estill E<lt>JamesEstill at gmail.comE<gt>

=cut

#-----------------------------+
# INCLUDES                    |
#-----------------------------+
use strict;
use DBI;
use Getopt::Long;

#-----------------------------+
# VARIABLE SCOPE              |
#-----------------------------+
my $usrname = $ENV{DBI_USER};  # User name to connect to database
my $pass = $ENV{DBI_PASSWORD}; # Password to connect to database
my $dsn = $ENV{DBI_DSN};       # DSN for database connection
my $db;                        # Database name (ie. biosql)
my $host;                      # Database host (ie. localhost)
my $driver;                    # Database driver (ie. mysql)
my $help = 0;                  # Display help
my $quiet = 0;                 # Run the program in quiet mode
                               # will not prompt for command line options

#-----------------------------+
# COMMAND LINE OPTIONS        |
#-----------------------------+
my $ok = GetOptions("d|dsn=s"    => \$dsn,
                    "u|dbuser=s" => \$usrname,
                    "p|dbpass=s" => \$pass,
		    "driver=s"   => \$driver,
		    "dbname=s"   => \$db,
		    "host=s"     => \$host,
		    "q|quiet"    => \$quiet,
		    "h|help"     => \$help);

# SHOW HELP
if($help || (!$ok)) {
    system("perldoc $0");
    exit($ok ? 0 : 2);
}

# A full dsn can be passed at the command line or components
# can be put together
unless ($dsn) {
    # Set default values if none given at command line
    $db = "biosql" unless $db; 
    $host = "localhost" unless $host;
    $driver = "mysql" unless $driver;
    $dsn = "DBI:$driver:database=$db;host=$host";
} else {
    # We need to parse the database name, driver etc from the dsn string
}

#-----------------------------+
# GET DB PASSWORD             |
#-----------------------------+
# This prevents the password from being globally visible
# I don't know what happens with this in anything but Linux
# so I may need to get rid of this or modify it 
# if it crashes on other OS's
unless ($pass) {
    print "\nEnter password for the user $usrname\n";
    system('stty', '-echo') == 0 or die "can't turn off echo: $?";
    $pass = <STDIN>;
    system('stty', 'echo') == 0 or die "can't turn on echo: $?";
    chomp $pass;
}

# Show variables for debug
print "USR:\t$usrname\n";
print "DSN:\t$dsn\n";

#-----------------------------+
# CREATE DATABASE IF NEEDED   |
#-----------------------------+
# This will currently only work for mysql
# I don't really know how to do this in PostgresSQL or Oracle
if ($driver =~ "mysql") {
    &CreateMySQLDB($usrname, $pass, $db);
}

#-----------------------------+
# CONNECT TO THE DATABASE     |
#-----------------------------+
my $dbh = &ConnectToDb($dsn, $usrname, $pass);


exit;

#-----------------------------------------------------------+
# SUBFUNCTIONS                                              |
#-----------------------------------------------------------+
# I will try to use the database connection code from the
# existing BioSQL PERL code.

sub ConnectToDb {
    my ($cstr) = @_;
    return ConnectToMySQL(@_) if $cstr =~ /:mysql:/i;
    return ConnectToPg(@_) if $cstr =~ /:pg:/i;
    die "can't understand driver in connection string: $cstr\n";
}

sub ConnectToMySQL {
    
    my ($cstr, $user, $pass) = @_;
    
    my $dbh = DBI->connect($cstr, 
			   $user, 
			   $pass, 
			   {PrintError => 0, RaiseError => 1});
    
    $dbh || &error("DBI connect failed : ",$dbh->errstr);
    
    return($dbh);
}

sub CreateMySQLDB {
    #-----------------------------+
    # CREATE MySQL DATABASE IF IT |
    # DOES NOT EXIST              |
    #-----------------------------+
    my $CrUser = $_[0];           # User name for creating MySQL DB
    my $CrPass = $_[1];           # User password for creaing MySQL DB
    my $CrDB = $_[2];             # Name of the database to create

    print "Checking status of database\n";
    
    my $ShowDb = "mysqlshow -u $CrUser -p$CrPass";
    my @DbList = `$ShowDb`;
    chomp( @DbList );
    
    my $DbExists = '0';
    
    #-----------------------------+
    # DOES THE DB ALREADY EXIST   |
    #-----------------------------+
    my $IndDb;                     # Individual DB in the mysql DB list
    foreach $IndDb (  @DbList ) { 
	if ( $IndDb =~ /$CrDB/ ) {
	    # Print statements for debug
	    #print "\a";            # Sounds alarm
	    #print "The database does exist.\n";
	    $DbExists = '1';
	} # End of check DbName 
    } # End of For each Individual Database
    
    #-----------------------------+
    # CREATE DB IF NEEDED         |
    #-----------------------------+
    # This currently assumes that $CrUser has the ability to create databases
    unless ($DbExists) {
	print "The database $CrDB does not exist.\n";

	my $Question = "Do you want to create a new database named $CrDB?";
	my $MakeDb =  &UserFeedback ($Question);
	
	if ($MakeDb =~ "Y"){
	    my $CreateDBCmd = "mysqladmin create $CrDB -u $CrUser -p$CrPass";
	    system ($CreateDBCmd);
	} else {
	    # If the user does not want to create the databse,
	    # exit the program. This could happen if there was a 
	    # a simple typo in the database name.
	    exit;
	}

    } # End of unless $DbExists
    
} # End of CreateMySQLDB subfunction


sub UserFeedback
{
#-----------------------------+
# USER FEEDBACK SUBFUNCTION   |
#-----------------------------+
    
    my $Question = $_[0];
    my $Answer;
    
    print "\n$Question \n";
    
    while (<>)
    {
	chop;
	if ( ($_ eq 'y') || ($_ eq 'Y') || ($_ eq 'yes') || ($_ eq 'YES') )
	{
	    $Answer = "Y";
	    return $Answer;
	}
	elsif ( ($_ eq 'n') || ($_ eq 'N') || ($_ eq 'NO') || ($_ eq 'no') )
	{
	    $Answer = "N";
	    return $Answer;
	}
	else
	{
	    print "\n$Question \n";
	}
    }
    
} # End of UserFeedback subfunction

=head1 HISTORY

Started: 05/30/2007

Updated: 05/31/2007

=cut

#-----------------------------------------------------------+
# HISTORY                                                   |
#-----------------------------------------------------------+
# 05/30/2007
# - Started PhyInit.pl
# - Pod documentation started
# - Begin the database connection code
# 05/31/2007
# - Modified command line
# - Added code to create dsn if not provided at command line
# - Added password input with echo off for security
# - Added CreateMySQLDB subfunction
# - Added UserFeedback subfunction
