#!/usr/bin/perl -w
#/////////////////////////////////////////////////////////////
#////////////////////////////////////////////////////////////
#
# WARNING: SCRIPT UNDER CURRENT DEVEOPMENT
#
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
#-----------------------------------------------------------+
#                                                           |
# phyexport.pl - Export phylodb data to common file formats |
#                                                           |
#-----------------------------------------------------------+
#                                                           |
#  AUTHOR: James C. Estill                                  |
# CONTACT: JamesEstill_at_gmail.com                         |
# STARTED: 06/18/2007                                       |
# UPDATED: 07/20/2007                                       |
#                                                           |
# DESCRIPTION:                                              | 
#  Export data from the PhyloDb database to common file     |
#  file formats.                                            |
#                                                           |
# LICENSE:                                                  |
#  GNU Lesser Public License                                |
#  http://www.gnu.org/licenses/lgpl.html                    |  
#                                                           |
#-----------------------------------------------------------+
#
# TO DO:
# - Update POD documentation
# - Allow for using a root_name to name all of the output trees
#   or use the tree_name from the database as the output name
#   when exporting trees.
#
# NOTE:
# - This will initially only support export of a single tree.
 
=head1 NAME 

phyexport.pl - Export phylodb data to common file formats

=head1 SYNOPSIS

  Usage: phyexport.pl
        --dsn         # The DSN string the database to connect to
                      # Must conform to:
                      # 'DBI:mysql:database=biosql;host=localhost' 
        --outfile     # Full path to output file that will be created.
        --dbuser      # User name to connect with
        --dbpass      # Password to connect with
        --dbname      # Name of database to use
        --driver      # "mysql", "Pg", "Oracle" (default "mysql")
        --host        # optional: host to connect with
        --format      # "newick", "nexus" (default "newick")
        --tree        # Name of the tree to export
        --parent-node # Node to serve as root for a subtree export
        --help        # Print this help message
        --quiet       # Run the program in quiet mode.
        --db-node-id  # Preserve DB node names in export

=head1 DESCRIPTION

Export a phylodb Tree to a specified output format.

=head1 ARGUMENTS

=over

=item -o, --outfile

The full path of the output file that will be created.

=item -f, --format
    
    File format to export the tree to [ie NEXUS].
    
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

=item --parent-node

Node id to serve as the root for a subtree export.
    
=item -h, --help

Print the help message.

=item -q, --quiet

Print the program in quiet mode. No output will be printed to STDOUT
and the user will not be prompted for intput.

=item --db-node-id

Preserve database node ids when exporting the tree. For nodes that
have existing labels in the label field, the node_id from the database
will be indicated in parentesis.

=back

=head1 AUTHORS

James C. Estill E<lt>JamesEstill at gmail.comE<gt>

=cut

print "Staring $0 ..\n";

#Package this as phytools for now
package PhyloDB;

#-----------------------------+
# INCLUDES                    |
#-----------------------------+
use strict;
use DBI;
use Getopt::Long;
use Bio::TreeIO;                # creates Bio::Tree::TreeI objects
use Bio::Tree::TreeI;
use Bio::Tree::Node;
use Bio::Tree::NodeI;

#-----------------------------+
# VARIABLE SCOPE              |
#-----------------------------+
my $ver = "Dev: 07/20/2007";   # Program version

my $usrname = $ENV{DBI_USER};  # User name to connect to database
my $pass = $ENV{DBI_PASSWORD}; # Password to connect to database
my $dsn = $ENV{DBI_DSN};       # DSN for database connection
my $outfile;                   # Full path to output file to create
my $format = 'newick';         # Data format used in infile
my $db;                        # Database name (ie. biosql)
my $host;                      # Database host (ie. localhost)
my $driver;                    # Database driver (ie. mysql)
my $tree_name;                 # The name of the tree
                               # For files with multiple trees, this may
                               # be used as a base name to name the trees with
my @trees = ();                # Array holding the names of the trees that will
                               # be exported
my $statement;                 # Var to hold SQL statement string
my $sth;                       # Statement handle for SQL statement object


#our $tree;                      # Tree object, this has to be a package
#my $tree = new Bio::Tree::Tree() ||
#	die "Can not create the tree object.\n";

my $root;                       # The node_id of the root of the tree
                                # that will be exported
my $parent_node;                # The parent node that will serve as the
                                # clipping point for exporting a 
                                # new tree
my $parent_edge;                # A parend edge that will serve as the 
                                # clipping point for exporing a tree
                                # May not implement this ..
our $tree;                      # Tree object, this has to be a package
#                               # level variable since we will modify this
                                # in a subfunction below.
                                # This is my first attempt to work with
                                # a package level var.

# BOOLEANS
my $show_help = 0;             # Display help
my $quiet = 0;                 # Run the program in quiet mode
                               # will not prompt for command line options
my $show_node_id = 0;          # Include the database node_id in the output
my $show_man = 0;              # Show the man page via perldoc
my $show_usage = 0;            # Show the basic usage for the program
my $show_version = 0;          # Show the program version
my $verbose;                   # Boolean, but chatty or not

#-----------------------------+
# COMMAND LINE OPTIONS        |
#-----------------------------+
my $ok = GetOptions("d|dsn=s"       => \$dsn,
                    "u|dbuser=s"    => \$usrname,
                    "o|outfile=s"   => \$outfile,
                    "f|format=s"    => \$format,
                    "p|dbpass=s"    => \$pass,
		    "driver=s"      => \$driver,
		    "dbname=s"      => \$db,
		    "host=s"        => \$host,
		    "t|tree=s"      => \$tree_name,
		    "parent-node=s" => \$parent_node,
		    "db-node-id"    => \$show_node_id,
		    "q|quiet"       => \$quiet,
                    "verbose"       => \$verbose,
		    "version"       => \$show_version,
		    "man"           => \$show_man,
		    "usage"         => \$show_usage,
		    "h|help"        => \$show_help);

# TO DO: Normalize format to 

# Exit if format string is not recognized
#print "Requested format:$format\n";
$format = &in_format_check($format);

## SHOW HELP
#if($show_help || (!$ok)) {
#    system("perldoc $0");
#    exit($ok ? 0 : 2);
#}

#-----------------------------+
# SHOW REQUESTED HELP         |
#-----------------------------+

if ($show_usage) {
    print_help("");
}

if ($show_help || (!$ok) ) {
    print_help("full");
}

if ($show_version) {
    print "\n$0:\nVersion: $ver\n\n";
    exit;
}

if ($show_man) {
    # User perldoc to generate the man documentation.
    system("perldoc $0");
    exit($ok ? 0 : 2);
}

print "Staring $0 ..\n" if $verbose; 


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
    print "\tDSN:\t$dsn\n";
    print "\tPRE:\t$prefix\n";
    print "\tDRIVER:\t$driver\n";
    print "\tSUF:\t$suffix\n";
    print "\tDB:\t$db\n";
    print "\tHOST:\t$host\n";
    # The following not required
    print "\tTREES\t$tree_name\n" if $tree_name;
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


#-----------------------------+
# CONNECT TO THE DATABASE     |
#-----------------------------+
# Commented out while I work on fetching tree structure
my $dbh = &connect_to_db($dsn, $usrname, $pass);

#-----------------------------+
# EXIT HANDLER                |
#-----------------------------+
#END {
#    &end_work($dbh);
#}

#-----------------------------+
# PREPARE SQL STATEMENTS      |
#-----------------------------+

# The following works in MySQL 06/20/2007
my $sel_trees = &prepare_sth($dbh, "SELECT name FROM tree");

# The following works in MySQL 06/20/2007
my $sel_root = &prepare_sth($dbh, 
			    "SELECT n.node_id, n.label FROM tree t, node n "
			    ."WHERE t.node_id = n.node_id AND t.name = ?");

# Select the child nodes
my $sel_chld = &prepare_sth($dbh, 
			    "SELECT n.node_id, n.label, e.edge_id "
			    ."FROM node n, edge e "
			    ."WHERE n.node_id = e.child_node_id "
			    ."AND e.parent_node_id = ?");

# Select edge attribute values
my $sel_attrs = &prepare_sth($dbh,
			     "SELECT t.name, eav.value "
			     ."FROM term t, edge_attribute_value eav "
			     ."WHERE t.term_id = eav.term_id "
			     ."AND eav.edge_id = ?");

# Currently doing the following as a fetch_node_label subfunction 
## Select the node label 
#my $sel_label = &prepare_sth($dbh,
#			     "SELECT label FROM node WHERE node_id = ?");

#-----------------------------+
# GET THE TREES TO PROCESS    |
#-----------------------------+
# Check to see if the tree does exist in the database
# throw error message if it does not

# Multiple trees can be passed in the command lined
# we therefore need to split tree name into an array
if ($tree_name) {
    @trees = split( /\,/ , $tree_name );
} else {
    print "No tree name issued at the command line.\n";
}


if (! (@trees && $trees[0])) {
    @trees = ();
    execute_sth($sel_trees);
    while (my $row = $sel_trees->fetchrow_arrayref) {
	push(@trees,$row->[0]);
    }
}


# Add warning here to tell the user how many trees will be 
# created if a single tree was not specified


## SHOW THE TREES THAT WILL BE PROCESSED
my $num_trees = @trees;
print "TREES TO EXPORT ($num_trees)\n";
foreach my $IndTree (@trees) {
    print "\t$IndTree\n";
}

#-----------------------------------------------------------+
# FOR EACH INDIVIDUAL TREE IN THE TREES LIST                | 
#-----------------------------------------------------------+
foreach my $ind_tree (@trees) {

    #-----------------------------+
    # CREATE A NEW TREE OBJECT    |
    #-----------------------------+
    print "\tCreating a new tree object.\n";
    $tree = new Bio::Tree::Tree() ||
	die "Can not create the tree object.\n";


    #///////////////////////////////////////////////////
    # WORKING HERE
    # TRYING TO DEFINE ROOT AS THE 
    #\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
    
    if ($parent_node) {
	# Set the root to the parent node passed at cmd line
	$root->[0] = $parent_node;
    }
    else {
	# Get the root to the entire tre
	execute_sth($sel_root, $ind_tree);
	$root = $sel_root->fetchrow_arrayref;
    }


    if ($root) {
	print "\nProcessing tree: $ind_tree \n";
	#print "\tRoot Node: ".$root->[0]."\n";
	
	# ADD THE ROOT NODE TO THE TREE OBJECT
	my $node = new Bio::Tree::Node( '-id' => $root->[0]);
	$tree->set_root_node($node);
	
	# test of find node here, this appears to work 06/22/2007
	my @par_node = $tree->find_node( -id => $root->[0] );
	my $num_par_nodes = @par_node;
	
    } 
    else {
	print STDERR "no tree with name '$ind_tree'\n";
	next;
    }

    #-----------------------------+
    # LOAD TREE NODES             |
    #-----------------------------+
    # This will need to load the tree nodes to the tre1e object
    #&load_tree_nodes($sel_chld,$root,$sel_attrs, $tree);
    &load_tree_nodes($sel_chld,$root,$sel_attrs);

    #-----------------------------+
    # LOAD NODE VARIABLES         | 
    #-----------------------------+
    # At this point, all of the nodes should be loaded to the tree object
    my @all_nodes = $tree->get_nodes;
    
    foreach my $ind_node (@all_nodes) {
	
        &execute_sth($sel_attrs,$ind_node);
	
        my %attrs = ();

        while (my $row = $sel_attrs->fetchrow_arrayref) {
            $attrs{$row->[0]} = $row->[1];
        }

	#-----------------------------+
	# BOOTSTRAP                   |
	#-----------------------------+
	# Example of adding the boostrap info
	#$ind_node->bootstrap('99');
	# Example of fetching support value from the attrs
        #$attrs{'support value'} if $attrs{'support value'};
	if ( $attrs{'support value'} ) {
	    #print "\t\tSUP:".$attrs{'support value'}."\n";
	    $ind_node->bootstrap( $attrs{'support value'} );
	}
	
	#-----------------------------+
	# BRANCH LENGTH               |
	#-----------------------------+
	# Example of adding the branch length info 
	#$ind_node->branch_length('10');
	# Example of fetching the branch length from the attrs
        #print ":".$attrs{'branch length'} if $attrs{'branch length'}
	if ($attrs{'branch length'} ) {
	    $ind_node->branch_length( $attrs{'branch length'} );
	}

	#-----------------------------+
	# SET NODE ID                 |
	#-----------------------------+
	# TO DO 
	# INCLUDE OPTION TO USE DB ID'S FOR INTERNAL NODES
	# If null in the original tree, put null here
	#my $sql = "SELECT label FROM node WHERE node_id = $ind_node";
	
	if ($show_node_id) {

	    my $node_label = fetch_node_label($dbh, $ind_node->id());
	    
	    # If a node label exists in the database, show the 
	    # database node id in parenthesis
	    if ($node_label) {
		# At this point the node id in the database is saved
		# as $ind_node->id, the node label from the original
		# tree is stored as $node_label
		my $new_node_id = $node_label."_node_".$ind_node->id;
		$ind_node->id($new_node_id);
	    }
	}
	else {
	    
	    # Otherwise overwrite the node id with the value in
	    # the node_label field of the node table
	    my $node_label = fetch_node_label($dbh, $ind_node->id());
	    
	    if ($node_label) {
		$ind_node->id($node_label);
	    } else {
		$ind_node->id('');
	    }

	} # End of  if show_node_id
	
    }
    
    #-----------------------------+
    # EXPORT TREE FORMAT          |
    #-----------------------------+
    # The following two lines used for code testing
    #my $treeio = new Bio::TreeIO( '-format' => $format );
    #print "OUTPUT TREE AS $format:\n";
    my $treeio = Bio::TreeIO->new( -format => $format,
				   -file => '>'.$outfile)
	|| die "Could not open output file:\n$outfile\n";
    
    
    # The following code writes the tree out to the STDOUT
    my $treeout_here = Bio::TreeIO->new( -format => $format );
    
    $treeout_here->write_tree($tree); 


    $treeio->write_tree($tree);

#    # The follwoing writes the code to the output file
#    # but for some reason it does not return true ..
#    if ( $treeio->write_tree($tree) ) {
#	print "\tTree exported to:\n\t$outfile\n";
#    };
    
#    $treeio->write_tree($PhyloDB::tree) ||
#	die "Cound not write tree to output file.";

#    print "\tTree exported to:\n\t$outfile\n";
    

} # End of for each tree


# End of program
print "\n$0 has finished.\n";

exit;

#-----------------------------------------------------------+
# SUBFUNCTIONS                                              |
#-----------------------------------------------------------+

#sub fetch_

sub load_tree_nodes {

    my $sel_chld_sth = shift;# SQL to select children
    my $root = shift;        # reference to the root
    my $sel_attrs = shift;   # SQL to select attributes

    my @children = ();

    &execute_sth($sel_chld_sth,$root->[0]);

    # Push results to the children array
    while (my $child = $sel_chld_sth->fetchrow_arrayref) {
        push(@children, [@$child]);
    }
    
    # For all of the children, add the descendent node to
    # the tree object and call the load_tree_nodes subfunction
    # recursively for the resulting children nodes
    for(my $i = 0; $i < @children; $i++) {

	# The following used for debug
	#print "\t||".$root->[0]."-->".$children[$i][0]."||\n";

	my ($par_node) = $PhyloDB::tree->find_node( '-id' => $root->[0] );
	
	# Check here that @par_node contains only a single node object
	my $nodeChild = new Bio::Tree::Node( '-id' => $children[$i][0] );
	$par_node->add_Descendent($nodeChild);

	&load_tree_nodes($sel_chld_sth, $children[$i], $sel_attrs);

    }

} # end of load_tree_nodes


sub fetch_node_label {

    # $dbh is the database handle
    # $node_id is the database node_id
    my ($dbh, $node_id) = @_;
    my ($sql, $cur, $result, @row);
    
    $sql = "SELECT label FROM node WHERE node_id = $node_id";
    $cur = $dbh->prepare($sql);
    $cur->execute();
    @row=$cur->fetchrow;
    $result=$row[0];
    $cur->finish();
    #print "\t\t$result\n";
    return $result;

}

sub end_work {
# Copied from load_itis_taxonomy.pl
    
    my ($dbh, $commit) = @_;
    
    # skip if $dbh not set up yet, or isn't an open connection
    return unless $dbh && $dbh->{Active};
    # end the transaction
    my $rv = $commit ? $dbh->commit() : $dbh->rollback();
    if(!$rv) {
	print STDERR ($commit ? "commit " : "rollback ").
	    "failed: ".$dbh->errstr;
    }
    $dbh->disconnect() unless defined($commit);
    
}

sub in_format_check {
    # TODO: Need to convert this to has lookup
    # This will try to make sense of the format string
    # that is being passed at the command line
    my ($In) = @_;  # Format string coming into the subfunction
    my $Out;         # Format string returned from the subfunction
    
    # NEXUS FORMAT
    if ( ($In eq "nexus") || ($In eq "NEXUS") || 
	 ($In eq "nex") || ($In eq "NEX") ) {
	return "nexus";
    };

    # NEWICK FORMAT
    if ( ($In eq "newick") || ($In eq "NEWICK") || 
	 ($In eq "new") || ($In eq "NEW") ) {
	return "newick";
    };

    # NEW HAMPSHIRE EXTENDED
    if ( ($In eq "nhx") || ($In eq "NHX") ) {
	return "nhx";
    };
    
    # LINTREE FORMAT
    if ( ($In eq "lintree") || ($In eq "LINTREE") ) {
	return "lintree";
    }

    die "Can not intrepret file format:$In\n";

}

sub connect_to_db {
    my ($cstr) = @_;
    return connect_to_mysql(@_) if $cstr =~ /:mysql:/i;
    return connect_to_pg(@_) if $cstr =~ /:pg:/i;
    die "can't understand driver in connection string: $cstr\n";
}

sub connect_to_pg {

	my ($cstr, $user, $pass) = @_;
	
	my $dbh = DBI->connect($cstr, $user, $pass, 
                               {PrintError => 0, 
                                RaiseError => 1,
                                AutoCommit => 0});
	$dbh || &error("DBI connect failed : ",$dbh->errstr);

	return($dbh);
} # End of ConnectToPG subfunction


sub connect_to_mysql {
    
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
#    my ($dbh) = @_;
    my $sth = $dbh->prepare(@_);
    die "failed to prepare statement '$_[0]': ".$dbh->errstr."\n" unless $sth;
    return $sth;
}

sub execute_sth {
    
    # I would like to return the statement string here to figure 
    # out where problems are.
    
    # Takes a statement handle
    my $sth = shift;

    my $rv = $sth->execute(@_);
    unless ($rv) {
	$dbh->disconnect();
	die "failed to execute statement: ".$sth->errstr."\n"
    }
    return $rv;
} # End of execute_sth subfunction

sub last_insert_id {

    #my ($dbh,$table_name,$driver) = @_;
    
    # The use of last_insert_id assumes that the no one
    # is interleaving nodes while you are working with the db
    my $dbh = shift;
    my $table_name = shift;
    my $driver = shift;

    # The following replace by sending driver info to the sufunction
    #my $driver = $dbh->get_info(SQL_DBMS_NAME);
    if (lc($driver) eq 'mysql') {
	return $dbh->{'mysql_insertid'};
    } elsif ((lc($driver) eq 'pg') || ($driver eq 'PostgreSQL')) {
	my $sql = "SELECT currval('${table_name}_pk_seq')";
	my $stmt = $dbh->prepare_cached($sql);
	my $rv = $stmt->execute;
	die "failed to retrieve last ID generated\n" unless $rv;
	my $row = $stmt->fetchrow_arrayref;
	$stmt->finish;
	return $row->[0];
    } else {
	die "don't know what to do with driver $driver\n";
    }
} # End of last_insert_id subfunction

# The following pulled directly from the DBI module
# this is an attempt to see if I can get the DSNs to parse 
# for some reason, this is returning the driver information in the
# place of scheme

sub parse_dsn {
    my ($dsn) = @_;
    $dsn =~ s/^(dbi):(\w*?)(?:\((.*?)\))?://i or return;
    my ($scheme, $driver, $attr, $attr_hash) = (lc($1), $2, $3);
    $driver ||= $ENV{DBI_DRIVER} || '';
    $attr_hash = { split /\s*=>?\s*|\s*,\s*/, $attr, -1 } if $attr;
    return ($scheme, $driver, $attr, $attr_hash, $dsn);
}

sub print_help {

    # Print requested help or exit.
    # Options are to just print the full 
    my ($opt) = @_;

    my $usage = "USAGE:\n". 
	"  phyexport.pl -i InFile -o OutFile";
    my $args = "REQUIRED ARGUMENTS:\n".
	"  --dsn          # Not really. just here for now.\n".
	"\n".
	"OPTIONS:\n".
	"  --dbname       # Name of the database to connect to\n".
	"  --host         # Database host\n".
	"  --driver       # Driver for connecting to the database\n".
	"  --dbuser       # Name to log on to the database with\n".
	"  --dbpass       # Password to log on to the database with\n".
	"  --tree         # Name of the tree to optimize\n".
	"  --version      # Show the program version\n".     
	"  --usage        # Show program usage\n".
	"  --help         # Show this help message\n".
	"  --man          # Open full program manual\n".
	"  --verbose      # Run the program with maximum output\n". 
	"  --quiet        # Run program with minimal output\n";
	
    if ($opt =~ "full") {
	print "\n$usage\n\n";
	print "$args\n\n";
    }
    else {
	print "\n$usage\n\n";
    }
    
    exit;
}

=head1 HISTORY

Started: 06/18/2007

Updated: 07/20/2007

=cut

#-----------------------------------------------------------+
# HISTORY                                                   |
#-----------------------------------------------------------+
# 06/18/2007 - JCE
# - Started program, copied subfunctions from phyimport.pl
# - Added print_trees subfunction from print-trees.pl
# - Added print_tree_nodes subfunction from print-trees.pl
# 
# 06/19/2007 - JCE
# - added the create a new tree object and tested adding
#   nodes to the tree
# - Moving the subfunction for each tree to the main body
#   of the code
#
# 06/21/2007 - JCE
# - Working more with the Bio::Tree object
#
# 06/22/2007 - JCE
# - Finally have a working base code to expand from
# - Can export file to Bio::Tree supported formats
# - Added bootstrap values to node objects
# - Added edge lengths to node objects
# - Added the original node id to the node object and 
#   overwrite the id assigned by the database
#   It may make sense to leave this if the user wants
#   to pick branches to expand.
#
# 07/06/2007 - JCE
# - Working on only exporing a subtree based on a single node
# - This uses the parent_node variable
#
# 07/10/2007 - JCE
# - Fixed problem exporting tree to file, filehandle was 
#   not being passed to the BioTree object
#
# 07/11/2007 - JCE
# - Added --db-node-id flag to include the database node id
#   in the exported tree, the default is to rever to the node
#   labels used in the original tree as stores in node.label
# - Added --parent-node to serve as the base node to export
#   a subtre
#
# 07/20/2007 - JCE
# - Adding usage, help, man, and version to command line opts
