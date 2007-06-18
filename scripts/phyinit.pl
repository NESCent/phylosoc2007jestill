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
# UPDATED: 06/07/2007                                       |
#                                                           |
# DESCRIPTION:                                              | 
#  Initialize a BioSQL database with the phyloinformatics   |
#  tables. This will initially only work with MySQL, but    |
#  other databases can be made available. I will also       | 
#  initially assume that BioSQL already exists, and will    |
#  just add the phyloinforamtics tables                     |
#                                                           |
# LICENSE:                                                  |
#  GNU Lesser Public License                                |
#  http://www.gnu.org/licenses/lgpl.html                    |  
#                                                           |
#-----------------------------------------------------------+
#
# THIS SOFTWARE COMES AS IS, WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTY. USE AT YOUR OWN RISK.

# TO DO:
# - Create the non-phylo tables components of BioSQL
# - Run appropriate SQL code in sqldir
# - Can run system cmd like
#   source /home/jestill/cvsloc/biosql-schema/sql/biosqldb-mysql.sql
#   to establish the SQL schema instead of putting code here

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
        --sqldir     # SQL Dir that contains the SQL to create tables
                   

=head1 DESCRIPTION

Initialize a BioSQL database with the phyloinformatics tables. This will
initially only work with MySQL, but other databases can later be made 
available with the driver argument.

=head1 ARGUMENTS

=over

=item -d, --dsn

the DSN of the database to connect to; default is the value in the
environment variable DBI_DSN. If DBI_DSN has not been defined and
the string is not passed to the command line, the dsn will be 
constructed from --driver, --dbname, --host

Example: DBI:mysql:database=biosql;host=localhost

=item -u, --dbuser

The user name to connect with; default is the value in the environment
variable DBI_USER.

This user must have permission to create databases.

=item -p, --dbpass

password to connect with; default is the value in the environment
variable DBI_PASSWORD. If this is not provided at the command line
the user is prompted.

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

Hilmar Lapp, E<lt>hlapp at gmx.netE<gt>

Bill Piel, E<lt>william.piel at yale.eduE<gt>

=cut

#-----------------------------+
# INCLUDES                    |
#-----------------------------+
use strict;
use DBI;
use Getopt::Long;
#use Bio::Tree;

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
my $sqldir;                    # Directory that contains the sql to run
                               # to create the tables.
my $quiet = 0;                 # Run the program in quiet mode
                               # will not prompt for command line options

#-----------------------------+
# COMMAND LINE OPTIONS        |
#-----------------------------+
my $ok = GetOptions("d|dsn=s"    => \$dsn,
                    "u|dbuser=s" => \$usrname,
                    "p|dbpass=s" => \$pass,
		    "s|sqldir=s" => \$sqldir,
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
    # in the form of DBI:$driver:database=$db;host=$host
    # Other dsn strings will not be parsed properly
    # Split commands are often faster then regular expressions
    # However, a regexp may offer a more stable parse then splits do
    my ($cruft, $prefix, $suffix, $predb, $prehost); 
    ($prefix, $driver, $suffix) = split(/:/,$dsn);
    ($predb, $prehost) = split(/;/, $suffix);
    ($cruft, $db) = split(/=/,$predb);
    ($cruft, $host) = split(/=/,$prehost);
    # Print for debug
    print "\tPRE:\t$prefix\n";
    print "\tDRIVER:\t$driver\n";
    print "\tSUF:\t$suffix\n";
    print "\tDB:\t$db\n";
    print "\tHOST:\t$host\n";
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
print "DEBUG INFO\n";
print "\tUSER:\t$usrname\n";
print "\tDRIVER:\t$driver\n";
print "\tHOST:\t$host\n";
print "\tDB:\t$db\n";
print "\tDSN:\t$dsn\n";

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

#-----------------------------+
# CHECK FOR EXISTENCE OF      |
# PHYLO TABLES AND CREATE IF  |
# NEEDED                      |
#-----------------------------+
# If the sqldir is passed, then use the SQL there. However
# I decided to also do this as SQL statements within PERL 
# since that is the way I like to do things. JCE

# CHECK FOR EXISTENCE OF TABLES AND WARN USER THAT
# THE DATA IN THE EXISTING TABLES WILL BE LOST
# This provides a place for the user to back out before
# trashing any hard work that may be stored in existing tables.
# For the full database, this could be done by reading the
# tables from the MySQL database.
#
my @TblList = ("tree",
	       "node",
	       "edge",
	       "node_path",
	       "edge_attribute_value",
	       "node_attribute_value"
	       );

my @Tbl2Del;     # Tables that need to be deleted will be pushed to this list
my $Num2Del = 0; # The number of tables that will be deleted 
my $DelInfo = "";     # Info on the 

# DETERMINE IF ANY TABLES WOULD NEED TO BE DELETED
foreach my $Tbl (@TblList) {
    if (&DoesTableExist($dbh, $Tbl)) {
	#print "The table $tblQryCat already exits.\n";
	$Num2Del++;
	push @Tbl2Del, $Tbl;
	my $NumRecs = &HowManyRecords($dbh, $Tbl);
	$DelInfo = $DelInfo."\t".$Tbl."( ".$NumRecs." Records )\n";
    } # End of DoesTableExist
} # End of for each individual table

# WARN THE USER 
if ($Num2Del > 0) {

    print "\nThe following tables will be deleted:\n";
    print $DelInfo;
    my $question = "Do you want to delete the existing tables?";
    my $answer = &UserFeedback($question);

    if ($answer =~ "N"){
	print "The database was not create and ".
	    "no changes to the database were made.\n";
	print "Exiting program\n";
	exit;
    } else {

	# TURNING OFF FOREIGN KEYS CHECKS IS A TEMP FIX
	# This allows me to drop tables where 
	# ON DELTE CASCADE has not been set
	$dbh->do("SET FOREIGN_KEY_CHECKS=0;");

	foreach my $Tbl (@Tbl2Del){
	    print "Dropping table: $Tbl\n";
	    my $DropTable = "DROP TABLE $Tbl;";
	    #$dbh->do("DROP TABLE ".$Tbl." CASCADE;");
	    $dbh->do( $DropTable );
	} # End of foreach $Tbl

	$dbh->do("SET FOREIGN_KEY_CHECKS=1;");

    } # End of if answer 

} # End of Num2Del > 0

unless ($sqldir)
{

    my $AddIndex;       # Var to hold the Add Index statements
    
    #-----------------------------+  
    # TREE TABLE                  |
    #-----------------------------+ 
    my $CreateTree = "CREATE TABLE tree (".
	" tree_id INT(10) UNSIGNED NOT NULL auto_increment,".
	" name VARCHAR(32) NOT NULL,".
	" identifier VARCHAR(32),".
	" is_rooted ENUM ('FALSE', 'TRUE') DEFAULT 'TRUE',". 
	" node_id INT(10) UNSIGNED NOT NULL,".
	" PRIMARY KEY (tree_id),".
	" UNIQUE (name)".
	" ) TYPE=INNODB;";
    $dbh->do($CreateTree);
    
    # Add index to tree(node_id)
    # Index needed for Foreign Keys in INNODB tables
    $AddIndex = "CREATE INDEX node_node_id ON tree(node_id);";
    $dbh->do($AddIndex);

    #-----------------------------+
    # NODE                        |
    #-----------------------------+
    print "Creating table: node\n";
    my $CreateNode = "CREATE TABLE node (".
	" node_id INT(10) UNSIGNED NOT NULL auto_increment,".
	" label VARCHAR(255),".
	" tree_id INT(10) UNSIGNED NOT NULL,".
	" bioentry_id INT(10) UNSIGNED,".
	" taxon_id INT(10) UNSIGNED,".
	" left_idx INT(10) UNSIGNED,".
	" right_idx INT(10) UNSIGNED,".
	" PRIMARY KEY (node_id),".
	" UNIQUE (label,tree_id),".
	" UNIQUE (left_idx,tree_id),".
	" UNIQUE (right_idx,tree_id)".
	" ) TYPE=INNODB;";
    $dbh->do($CreateNode);
    
    $AddIndex = "CREATE INDEX node_tree_id ON node(tree_id);";
    $dbh->do($AddIndex);

    $AddIndex = "CREATE INDEX node_bioentry_id ON node(bioentry_id);";
    $dbh->do($AddIndex);

    $AddIndex = "CREATE INDEX node_taxon_id ON node(taxon_id);";
    $dbh->do($AddIndex);

    #-----------------------------+
    # EDGES                       |
    #-----------------------------+
    print "Creating table: edge\n";
    my $CreateEdge = "CREATE TABLE edge (".
	" edge_id INT(10) UNSIGNED NOT NULL auto_increment,".
	" child_node_id INT(10) UNSIGNED NOT NULL,".
	" parent_node_id INT(10) UNSIGNED NOT NULL,".
	" PRIMARY KEY (edge_id),".
	" UNIQUE (child_node_id,parent_node_id)".
	" ) TYPE=INNODB;";
    $dbh->do($CreateEdge);

    $AddIndex = "CREATE INDEX edge_parent_node_id ON edge(parent_node_id)";
    $dbh->do($AddIndex);
    
    #-----------------------------+
    # NODE PATH                   |
    #-----------------------------+
    print "Creating table: node_path\n";
    #Transitive closure over edges between nodes
    my $CreateNodePath = "CREATE TABLE node_path (".
	" child_node_id INT(10) UNSIGNED NOT NULL,".
	" parent_node_id INT(10) UNSIGNED NOT NULL,".
	" path TEXT,".
	" distance INTEGER,".
	" PRIMARY KEY (child_node_id,parent_node_id,distance)".
	" ) TYPE=INNODB;";
    $dbh->do($CreateNodePath);

    $AddIndex = "CREATE INDEX node_path_parent_node_id ON".
	" node_path(parent_node_id)";
    $dbh->do($AddIndex);

    #-----------------------------+
    # EDGE ATTRIBUTES             |
    #-----------------------------+
    print "Creating table: edge_attribute_value\n";
    my $CreateEdgeAtt = "CREATE TABLE edge_attribute_value (".
	" value text,".
	" edge_id INT(10) UNSIGNED NOT NULL,".
	" term_id INT(10) UNSIGNED NOT NULL,".
	" UNIQUE (edge_id,term_id)".
	" ) TYPE=INNODB;";
    $dbh->do($CreateEdgeAtt);

    $AddIndex = "CREATE INDEX ea_val_term_id ON edge_attribute_value(term_id)";
    $dbh->do($AddIndex);
    
    #-----------------------------+
    # NODE ATTRIBUTE VALUES       |
    #-----------------------------+
    print "Creating table: node_attribute_value\n";
    my $CreateNodeAtt = "CREATE TABLE node_attribute_value (".
	" value text,".
	" node_id INT(10) UNSIGNED NOT NULL,".
	" term_id INT(10) UNSIGNED NOT NULL,".
	" UNIQUE (node_id,term_id)".
	" ) TYPE=INNODB;";
    $dbh->do($CreateNodeAtt);

    $AddIndex = "CREATE INDEX na_val_term_id ON node_attribute_value(term_id)";
    $dbh->do($AddIndex);

    #-----------------------------+
    # SET FOREIGN KEY CONSTRAINTS |
    #-----------------------------+
    print "Adding Foreign Key Constraints.\n";
    my $SetKey; # Var to hold the Set Key SQL string

    # May want to add ON DELETE CASCADE to these so
    # that I can DROP tables later


    # The inability to DEFER foreign KEYS with INNODB is a
    # problem late when trying to add node_id in PhyImport
    # I will attempt to remove this foreign key and see
    # if this fixes things JCE -- 06/06/2007
    $SetKey = "ALTER TABLE tree ADD CONSTRAINT FKnode".
	" FOREIGN KEY (node_id) REFERENCES node (node_id);";
# Deferarable foreign keys are not supported under MySQL InnoDB tables
# this causes problems with 
#	" DEFERRABLE INITIALLY DEFERRED;"; 
    $dbh->do($SetKey);
    
    $SetKey = "ALTER TABLE node ADD CONSTRAINT FKnode_tree".
	" FOREIGN KEY (tree_id) REFERENCES tree (tree_id);";
    $dbh->do($SetKey);
    
    $SetKey = "ALTER TABLE node ADD CONSTRAINT FKnode_bioentry".
	" FOREIGN KEY (bioentry_id) REFERENCES bioentry (bioentry_id);";
    $dbh->do($SetKey);

    $SetKey = "ALTER TABLE node ADD CONSTRAINT FKnode_taxon".
	" FOREIGN KEY (taxon_id) REFERENCES taxon (taxon_id);";
    $dbh->do($SetKey);

    $SetKey = "ALTER TABLE edge ADD CONSTRAINT FKedge_child".
	" FOREIGN KEY (child_node_id) REFERENCES node (node_id)".
	" ON DELETE CASCADE;";
    $dbh->do($SetKey);
    
    $SetKey = "ALTER TABLE edge ADD CONSTRAINT FKedge_parent".
	" FOREIGN KEY (parent_node_id) REFERENCES node (node_id)".
	" ON DELETE CASCADE;";
    $dbh->do($SetKey);

    $SetKey = "ALTER TABLE node_path ADD CONSTRAINT FKnpath_child".
	" FOREIGN KEY (child_node_id) REFERENCES node (node_id)".
	" ON DELETE CASCADE;";
    $dbh->do($SetKey);

    $SetKey = "ALTER TABLE node_path ADD CONSTRAINT FKnpath_parent".
	" FOREIGN KEY (parent_node_id) REFERENCES node (node_id)".
	" ON DELETE CASCADE;";
    $dbh->do($SetKey);

    $SetKey = "ALTER TABLE edge_attribute_value ADD CONSTRAINT FKeav_edge".
	" FOREIGN KEY (edge_id) REFERENCES edge (edge_id)".
	" ON DELETE CASCADE;";
    $dbh->do($SetKey);

    $SetKey = "ALTER TABLE edge_attribute_value ADD CONSTRAINT FKeav_term".
	" FOREIGN KEY (term_id) REFERENCES term (term_id);";
    $dbh->do($SetKey);

    $SetKey = "ALTER TABLE node_attribute_value ADD CONSTRAINT FKnav_node".
	" FOREIGN KEY (node_id) REFERENCES node (node_id)".
	" ON DELETE CASCADE;";
    $dbh->do($SetKey);

    $SetKey = "ALTER TABLE node_attribute_value ADD CONSTRAINT FKnav_term".
	" FOREIGN KEY (term_id) REFERENCES term (term_id);";
    $dbh->do($SetKey);


    # Commit changes, This is new as of 06/07/2007 since I
    # had AutoCommit on by default previosly
    $dbh->commit();

} # End of Unless $sqldir
# If sqldir is provided, then just create based on that
# This is better for maintenance since only the SQL
# code would need to be modified

# PRINT EXIT STATUS AND CLOSE DOWN SHOP
print "\nThe database $db has been initialized.\n";
$dbh->disconnect;

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
			   {PrintError => 0, 
			    RaiseError => 1,
			    AutoCommit => 0});
    
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

sub DoesTableExist
{
#-----------------------------+
# CHECK IF THE MYSQL TABLE    |
# ALREADY EXISTS              |
#-----------------------------+
# CODE FROM
# http://lena.franken.de/perl_hier/databases.html
# Makes use of global database handle dbh

    my ($dbh, $whichtable) = @_;
    #my ($whichtable) = @_;
    my ($table,@alltables,$found);
    @alltables = $dbh->tables();
    $found = 0;
    foreach $table (@alltables) {
	$found=1 if ($table eq "`".$whichtable."`");
    }
    # return true if table was found, false if table was not found
    return $found;
}


sub HowManyRecords
{
#-----------------------------+
# COUNT HOW MANY RECORDS      |
# EXIST IN THE MYSQL TABLE    |
#-----------------------------+
# CODE FROM
# http://lena.franken.de/perl_hier/databases.html

    my ($dbh, $whichtable) = @_;
    #my ($whichtable) = @_;
    my ($result,$cur,$sql,@row);

    $sql = "select count(*) from $whichtable";
    $cur = $dbh->prepare($sql);
    $cur->execute();
    @row=$cur->fetchrow;
    $result=$row[0];
    $cur->finish();
    return $result;

}

=head1 HISTORY

Started: 05/30/2007

Updated: 06/06/2007

=cut

#-----------------------------------------------------------+
# HISTORY                                                   |
#-----------------------------------------------------------+
# 05/30/2007 - JCE
# - Started PhyInit.pl
# - Pod documentation started
# - Begin the database connection code
# 05/31/2007 - JCE
# - Modified command line
# - Added code to create dsn if not provided at command line
# - Added password input with echo off for security
# - Added CreateMySQLDB subfunction
# - Added UserFeedback subfunction
# - Added DoesTableExist subfunction
# - Added parse of dsn string to: $db, $host, $driver 
# - Added H. Lapp and W. Piel as authors since I am using 
#   the SQL they created at the hackathon
# - Added SQL for creation of phylo tables
# 06/01/2007 - JCE
# - Added the HowManyRecords subfunction
# - Added code to check for table existence and number
#   of records that would be deleted. User can choose
#   not to delete
# - Added SQL for adding foreign key constraints to
#   phylo tables 
# 06/06/2007 - JCE
# - Modified SQL to create InnoDB tables instead of MyISAM 
#   tables, this will allow for transaction support
# - Added SET FOREIGN_KEY_CHECKS=0 to DROP TABLE CODE
# - Added indexes to the InnoDB tables to allow foreign
#   key constraints to work
# - Changed all INTEGER table values to INT(10) UNSIGNED
# 06/07/2007 - JCE
# - Modified scheme to fit Phylo-PG v 1.2 schema
# - Added AutoCommit => 0 to the DBI connection parameters
#   for MySQL 
# - Added $dbh->commit() and $dbh->disconnect() as appropriate
