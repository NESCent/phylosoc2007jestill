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
# UPDATED: 05/30/2007                                       |
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
# WARRANTY. USE AT YOUR OWN RISK.\

=head1 NAME 

PhyInit.pl - Initialize a phyloinformatics database.

=head1 SYNOPSIS

  Usage: PhyInit.pl
        --dbname     # name of database to use
        --dsn        # the DSN of the database to connect to
        --driver     # "mysql", "Pg", "Oracle" (default "mysql")
        --host       # optional: host to connect with
        --port       # optional: port to connect with
        --dbuser     # optional: user name to connect with
        --dbpass     # optional: password to connect with

=head1 DESCRIPTION

Initialize a BioSQL database with the phyloinformatics tables. This will
initially only work with MySQL, but other databases can be made available
with the drive option. 

=head1 ARGUMENTS

=over

=item -u, --dbuser

The user name to connect to; default is the value in the environment
variable DBI_USER.

This user must have permission to create databases.

=item -d, --dsn

the DSN of the database to connect to; default is the value in the
environment variable DBI_DSN.

=item -p, --dbpass

password to connect with; default is the value in the environment
variable DBI_PASSWORD

=item -h, --help

Print the help message.

=back

=head1 AUTHORS

James C. Estill

=cut

#-----------------------------+
# INCLUDES                    |
#-----------------------------+
use strict;
use DBI;
use Getopt::Long;

#-----------------------------+
# ESTABLISH VARIABLE SCOPE    |
#-----------------------------+
my $usrname = $ENV{DBI_USER};
my $pass = $ENV{DBI_PASSWORD};
my $dsn = $ENV{DBI_DSN};

my $ok = GetOptions("d|dsn=s", \$dsn,
                    "u|dbuser=s", \$usrname,
                    "p|dbpass=s", \$pass,
                    "tree=s", \$tree,
                    "h|help", sub { system("perldoc $0"); exit(0); });

my $dbh = &ConnectToDb($dsn, $usrname, $pass);

exit;

#-----------------------------------------------------------+
# SUBFUNCTIONS                                              |
#-----------------------------------------------------------+
# I will try to use the database connection code from the
# existing BioSQL PERL code.

sub ConnectToDb {
    my ($cstr) = @_;
    return ConnectToMysql(@_) if $cstr =~ /:mysql:/i;
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


=head1 HISTORY

Started: 05/30/2007

Updated: 05/30/2007

=cut

#-----------------------------------------------------------+
# HISTORY                                                   |
#-----------------------------------------------------------+
# 05/30/2007
# - Started PhyInit.pl
# - Pod documentation started
# - Begin the database connection code




