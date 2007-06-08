#!/usr/bin/perl -w
#-----------------------------------------------------------+
#                                                           |
# PhyImport.pl - Import data from common file formats       |
#                                                           |
#-----------------------------------------------------------+
#                                                           |
#  AUTHOR: James C. Estill                                  |
# CONTACT: JamesEstill_at_gmail.com                         |
# STARTED: 06/01/2007                                       |
# UPDATED: 06/07/2007                                       |
#                                                           |
# DESCRIPTION:                                              | 
#  Import NEXUS and Newick files from text files to the     |
#  PhyloDB.                                                 | 
#                                                           |
# LICENSE:                                                  |
#  GNU Lesser Public License                                |
#  http://www.gnu.org/licenses/lgpl.html                    |  
#                                                           |
#-----------------------------------------------------------+
#
# TO DO:
# - Update POD documentation
# - The internal nodes used by TreeI will not be the same
#   as the nodes used in the database so the DB ID will
#   need to be fetched when adding edges to the database.
#
 
=head1 NAME 

PhyImport.pl - Import phylogenetic trees from common file formats

=head1 SYNOPSIS

  Usage: PhyImport.pl
        --dsn        # The DSN string the database to connect to
        --dbuser     # user name to connect with
        --dbpass     # password to connect with
        --dbname     # Name of database to use
        --driver     # "mysql", "Pg", "Oracle" (default "mysql")
        --host       # optional: host to connect with
        --help       # Print this help message
        --quiet      # Run the program in quiet mode.

=head1 DESCRIPTION

Import NEXUS and Newick files from text files to the
PhyloDB. 

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

This user must have permission to add data to tables.

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

=cut

print "Staring PhyImport ..\n";

#-----------------------------+
# INCLUDES                    |
#-----------------------------+
use strict;
use DBI;
use Getopt::Long;
use Bio::TreeIO;                # creates Bio::Tree::TreeI objects
use Bio::Tree::TreeI;

#-----------------------------+
# VARIABLE SCOPE              |
#-----------------------------+
my $usrname = $ENV{DBI_USER};  # User name to connect to database
my $pass = $ENV{DBI_PASSWORD}; # Password to connect to database
my $dsn = $ENV{DBI_DSN};       # DSN for database connection
my $infile;                    # Full path to the input file to parse
my $format = "nex";            # Data format used in infile
my $db;                        # Database name (ie. biosql)
my $host;                      # Database host (ie. localhost)
my $driver;                    # Database driver (ie. mysql)
my $help = 0;                  # Display help
my $sqldir;                    # Directory that contains the sql to run
                               # to create the tables.
my $quiet = 0;                 # Run the program in quiet mode
                               # will not prompt for command line options
my $TreeName;                  # The name of the tree
                               # For files with multiple trees, this may
                               # be used as a base name to name the trees with
my $statement;                 # Var to hold SQL statement string
my $sth;                       # Statement handle for SQL statement object

#-----------------------------+
# COMMAND LINE OPTIONS        |
#-----------------------------+
my $ok = GetOptions("d|dsn=s"    => \$dsn,
                    "u|dbuser=s" => \$usrname,
                    "i|infile=s" => \$infile,
                    "f|format=s" => \$format,
                    "p|dbpass=s" => \$pass,
		    "s|sqldir=s" => \$sqldir,
		    "driver=s"   => \$driver,
		    "dbname=s"   => \$db,
		    "host=s"     => \$host,
		    "t|tree=s"   => \$TreeName,
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

# Commented out while I work through fetching the tree structure

unless ($pass) {
    print "\nEnter password for the user $usrname\n";
    system('stty', '-echo') == 0 or die "can't turn off echo: $?";
    $pass = <STDIN>;
    system('stty', 'echo') == 0 or die "can't turn on echo: $?";
    chomp $pass;
}


#-----------------------------+
# CONNECT TO THE DATABASE     |
#-----------------------------+
# Commented out while I work on fetching tree structure
my $dbh = &ConnectToDb($dsn, $usrname, $pass);

#-----------------------------+
# LOAD THE INPUT FILE         |
#-----------------------------+
print "\nLoading tree...\n";

my $TreeIn = new Bio::TreeIO(-file   => "$infile",
#			     -format => 'nexus') ||
			     -format => 'newick') ||
    die "Can not open tree file:\n$infile";


my $tree;
my $TreeNum = 1;

while( $tree = $TreeIn->next_tree ) {
    print "PROCESSING TREE NUM: $TreeNum\n";
    
    #-----------------------------+
    # TREE NAME                   |
    #-----------------------------+
    # If the tree has an id, then use the internal id
    # otherwise set to a new id. This will also need to
    # check to see if the id is already used in the database
    # If there are multiple trees in the database, and no
    # tree name has already been used, then append the tree num
    # to the $TreeName variable
    if ($tree->id) {
	print $tree->id."\n";
    } elsif ($TreeName ){
	$tree->id($TreeName);
	print "\tNo tree id was given.\n";
	print "\tTree name set to: ".$tree->id."\n";
    } else {
	print "ERROR: A Tree name must be part of the input file or".
	    " entered at the command line using the --tree option.\n".
	    " $0 -h for more information.\n";
	exit;
    }
    
    #//////////////////////////////////////////////////////
    # TO DO: Add check here to see if name already exists
    #        in the DB and allow user to set new name. 
    #\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    print "TREE NAME:\t".$tree->id."\n";
    
    # Add the Tree info to the tree table
    # Commented out while I work on the getting the
    # rest of the info
    $dbh->do("SET FOREIGN_KEY_CHECKS=0;");
    
    $statement = "INSERT INTO tree".
	" (name,node_id)".
	" VALUES ('".$tree->id."',0)";
    
    # The following for debug
    #print "\nSTATEMENT:\n$statement\n\n";
    $sth = &prepare_sth($dbh,$statement);
    &execute_sth($sth);
    
    # TURN FK CHECKS BACK ON
    $dbh->do("SET FOREIGN_KEY_CHECKS=0;");
    $dbh->commit();
    
    #-----------------------------+
    # DETERMINE IF TREE IS ROOTED |
    #-----------------------------+
    # IT may be better to do this after all nodes have been loaded
    # IF THE TREE IS ROOTED GET THE ROOT NODE 
    if ($tree->get_root_node) {
	my $root = $tree->get_root_node;
	# If the tree is rooted without an id, show the internal id
	#if ($root->id) {
	#    print "\tROOT:".$root->id."\n";
	#} else {
	#    print "\tROOT INTERNAL ID:".$root->internal_id."\n";
	#}
	#$statement = "INSERT INTO node (tree_id) VALUES ($id) ";


    } else {
	print "The tree is not rooted.\n";
	
	# SET is_rooted to FALSE
	#$statement = "";
    }
    $dbh->commit();
    

    # INSERT ROOT NODE IN node 


    #-----------------------------+
    # GET THE TAXA                |
    #-----------------------------+ 
#    my @taxa = $tree->get_leaf_nodes;
#    my $NumTax = @taxa;
#
#    # Print leaf node names
#    print "\tNUM TAX:$NumTax\n";
#    foreach my $IndNode (@taxa) {
#	print "\t\t".$IndNode->id."\n";
#    }

    #-----------------------------+
    # GET ALL OF THE NODES        |
    #-----------------------------+
    # Get nodes and show ancestor
    my @AllNodes = $tree->get_nodes;

    my $NumNodes = @AllNodes;

    # Add nodes to the database, and then convert the node id
    # from the name given in the input file to the name to be
    # used in the database
    
    foreach my $IndNode (@AllNodes) {
	
	# Load the node into the database
	# The tree_id is 
	# The tree name is uniqe so can use 
	# WHERE name = ?
	$statement = "INSERT INTO node (tree_id)".
	    " SELECT tree_id FROM tree WHERE name = ?";
	
	$sth = &prepare_sth($dbh,$statement);
	&execute_sth($sth,$tree->id);
	
#	$sth = &prepare_sth($sth,$tree->id)
	
        # First check to see that an id exists and then
	# load the information into the node_attribute table
        if ($IndNode->id) {
            my $anc = $IndNode->ancestor;
	    
        }
	

    } # End of for each IndNode
    

    # Temp exit while I work through this
    exit;


    # NOTE: It will be possible here to load the
    # node to the database first before loading the edges.
    # If the nodes have and id, this name will be loaded as 
    # a node attribute. At this point, the node_id assigned
    # by the database can be used to reset the value of 
    # $node->id. Then further use of the nodes in describing
    # edges can use $node-> to add edges

    #-----------------------------+
    # GET EDGES                   |
    #-----------------------------+
    # Need to load the nodes again since the node information
    # has changed

    print "\tALL EDGES:\n";
    foreach my $IndNode (@AllNodes) {
	
	# First check to see that an id exists
	if ($IndNode->id) {
	    my $anc = $IndNode->ancestor;
	    
	    # Only print edges when there is an ancestor node has 
	    # an id. This 
	    if ($anc->id) {
		print "\t\t".$IndNode->id;
		print "\t--\t";
		print $anc->id;
		print "\n";
	    }
	} 
    } # End of for each IndNode



    # Increment TreeNum
    $TreeNum++;


} 


# End of program
$dbh->disconnect();
print "\nPhyImport.pl has finished.\n";
exit;

#-----------------------------------------------------------+
# SUBFUNCTIONS                                              |
#-----------------------------------------------------------+

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

sub prepare_sth {
    my $dbh = shift;
    my $sth = $dbh->prepare(@_);
    die "failed to prepare statement '$_[0]': ".$dbh->errstr."\n" unless $sth;
    return $sth;
}

sub execute_sth {


    # Takes a statement handle
    my $sth = shift;

    my $rv = $sth->execute(@_);
    die "failed to execute statement: ".$sth->errstr."\n" unless $rv;
    return $rv;
}


=head1 HISTORY

Started: 05/30/2007

Updated: 06/07/2007

=cut

#-----------------------------------------------------------+
# HISTORY                                                   |
#-----------------------------------------------------------+
# 06/01/2007 - JCE
# - Program started
# 06/05/2007 - JCE
# - Updated POD documentation 
# 06/07/2007 - JCE
# -Adding the ability to read in a tree using Bio::TreeIO;
#  and Bio::Tree::TreeI;
# - Get nodes from tree object
# - Get edges from tree object
# - Added ConnnectToDb subfunction
# - Added ConnectToMySQL subfunction
# - Added exit when no tree name is available from command
#   line or from input file.
# - Added prepare_sth subfucntion
# - Added execute_sth subfunction
