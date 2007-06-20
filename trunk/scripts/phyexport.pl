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
# UPDATED: 06/19/2007                                       |
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
#
# NOTE:
# - This will initially only support export of a single tree.
 
=head1 NAME 

phyexport.pl - Export phylodb data to common file formats

=head1 SYNOPSIS

  Usage: phyexport.pl
        --dsn        # The DSN string the database to connect to
                     # Must conform to:
                     # 'DBI:mysql:database=biosql;host=localhost' 
        --outfile    # Full path to output file that will be created.
        --dbuser     # User name to connect with
        --dbpass     # Password to connect with
        --dbname     # Name of database to use
        --driver     # "mysql", "Pg", "Oracle" (default "mysql")
        --host       # optional: host to connect with
        --help       # Print this help message
        --quiet      # Run the program in quiet mode.
        --format     # "newick", "nexus" (default "newick")
        --tree       # Name of the tree to export

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
    
=item -h, --help

Print the help message.

=item -q, --quiet

Print the program in quiet mode. No output will be printed to STDOUT
and the user will not be prompted for intput.

=back

=head1 AUTHORS

James C. Estill E<lt>JamesEstill at gmail.comE<gt>

=cut

print "Staring $0 ..\n";

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
my $usrname = $ENV{DBI_USER};  # User name to connect to database
my $pass = $ENV{DBI_PASSWORD}; # Password to connect to database
my $dsn = $ENV{DBI_DSN};       # DSN for database connection
my $outfile;                   # Full path to output file to create
my $format = 'newick';         # Data format used in infile
my $db;                        # Database name (ie. biosql)
my $host;                      # Database host (ie. localhost)
my $driver;                    # Database driver (ie. mysql)
my $help = 0;                  # Display help
my $quiet = 0;                 # Run the program in quiet mode
                               # will not prompt for command line options
my $tree_name;                 # The name of the tree
                               # For files with multiple trees, this may
                               # be used as a base name to name the trees with
my @trees = ();                # Array holding the names of the trees that will
                               # be exported
my $statement;                 # Var to hold SQL statement string
my $sth;                       # Statement handle for SQL statement object

#-----------------------------+
# COMMAND LINE OPTIONS        |
#-----------------------------+
my $ok = GetOptions("d|dsn=s"    => \$dsn,
                    "u|dbuser=s" => \$usrname,
                    "o|outfile=s" => \$outfile,
                    "f|format=s" => \$format,
                    "p|dbpass=s" => \$pass,
		    "driver=s"   => \$driver,
		    "dbname=s"   => \$db,
		    "host=s"     => \$host,
		    "t|tree=s"   => \$tree_name,
		    "q|quiet"    => \$quiet,
		    "h|help"     => \$help);

# TO DO: Normalize format to 

# Exit if format string is not recognized
#print "Requested format:$format\n";
$format = &in_format_check($format);


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
    print "\tDSN:\t$dsn\n";
    print "\tPRE:\t$prefix\n";
    print "\tDRIVER:\t$driver\n";
    print "\tSUF:\t$suffix\n";
    print "\tDB:\t$db\n";
    print "\tHOST:\t$host\n";
    print "\tTREES\t$tree_name\n";
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
END {
    &end_work($dbh);
}

#-----------------------------+
# PREPARE SQL STATEMENTS      |
#-----------------------------+
# The following works in MySQL 06/20/2007
my $sel_trees = &prepare_sth($dbh, "SELECT name FROM tree");
# The following works in MySQL 06/20/2007
my $sel_root = &prepare_sth($dbh, 
			    "SELECT n.node_id, n.label FROM tree t, node n "
			    ."WHERE t.node_id = n.node_id AND t.name = ?");

my $sel_chld = &prepare_sth($dbh, 
			    "SELECT n.node_id, n.label, e.edge_id "
			    ."FROM node n, edge e "
			    ."WHERE n.node_id = e.child_node_id "
			    ."AND e.parent_node_id = ?");
my $sel_attrs = &prepare_sth($dbh,
			     "SELECT t.name, eav.value "
			     ."FROM term t, edge_attribute_value eav "
			     ."WHERE t.term_id = eav.term_id "
			     ."AND eav.edge_id = ?");

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


# For each tree in the array get the root node
foreach my $ind_tree (@trees) {
    execute_sth($sel_root, $ind_tree);
    my $root = $sel_root->fetchrow_arrayref;
    if ($root) {
	print "\nProcessing tree: $ind_tree \n";
#	print "\tRooted: $root\n"
	print "\tRoot Node: ".$root->[0]."\n"
    } else {
	print STDERR "no tree with name '$ind_tree'\n";
	next;
    }
    
    &load_tree_nodes($sel_chld,$root,$sel_attrs);

} # End of for each tree


exit;



#-----------------------------+
# CREATE A NEW TREE OBJECT    |
#-----------------------------+
# and set the root
my $tree = new Bio::Tree::Tree() ||
    die "Can not create the tree object.\n";

#-----------------------------+
# GET THE ROOT NODE           |
#-----------------------------+
my $node = new Bio::Tree::Node( '-id' => 'estill, james');
$tree->set_root_node($node);

# available args
# Args    : -descendents   => arrayref of descendents (they will be
#                             updated s.t. their ancestor point is this
#                             node)
#           -branch_length => branch length [integer] (optional)
#           -bootstrap     => value   bootstrap value (string)
#           -description   => description of node
#           -id            => human readable id for node


#$tree->set_root_node($node);


# Example of adding a child node
#
#my $nodeChild = new Bio::Tree::Node( '-id' => 'estill, jack');
#$node->add_Descendent($nodeChild);

my $nodeChild = new Bio::Tree::Node( '-id' => 'estill, jack');
$node->add_Descendent($nodeChild);

# NOTE - Branch length is the length between the node and its ancestor
# so the branch length should be added to the node after its child
# has been added

# FOR EVERY DESCENDENT FROM THE
# ROOT NODE

# Add a new node to the Tree object



# After all of the nodes have been added
# Add the id of the node from node.label


#-----------------------------+
# EXPORT THE TREE OBJECT      |
#-----------------------------+
my $treeio = new Bio::TreeIO( '-format' => 'newick' );

print "OUTPUT TREE AS NEWICK:\n";
$treeio->write_tree($tree);





















# End of program
print "\n$0 has finished.\n";
exit;

#-----------------------------------------------------------+
# SUBFUNCTIONS                                              |
#-----------------------------------------------------------+

sub load_tree_nodes {

# this subfunction is called recursively to fetch all of the chilren
# of a tree
# modified from print_tree_nodes subfunction
# the difference is that information is loaded to the $tree object
# instead of printing a text file. The required sql is passed
# to the subfunction

    my $sel_chld_sth = shift;
    my $root = shift;
    my $sel_attrs = shift;
    my @children = ();

    print "\tLoading child nodes.\n";

    &execute_sth($sel_chld_sth,$root->[0]);
    
    while (my $child = $sel_chld_sth->fetchrow_arrayref) {
        push(@children, [@$child]);
    }
    

    print "(" if @children;
    for(my $i = 0; $i < @children; $i++) {
        print "," unless $i == 0;
        &load_tree_nodes($sel_chld_sth, $children[$i], $sel_attrs);
    }
    print ")" if @children;

    print $root->[1] if $root->[1];

    if (@$root > 2) {
        execute_sth($sel_attrs,$root->[2]);
        my %attrs = ();
        while (my $row = $sel_attrs->fetchrow_arrayref) {
            $attrs{$row->[0]} = $row->[1];
        }
        print $attrs{'support value'} if $attrs{'support value'};
        print ":".$attrs{'branch length'} if $attrs{'branch length'};
    }

} # end of load_tree_nodes

sub export_trees {
# Modified from the print_trees subfunction
# the trees are loaded to an array
#use the subfunction like: export_trees($dbh, $tree);
# where $dbh is the database handle and
# $tree is the name of the tree to print
    my $dbh = shift;
    my @trees = @_;
    my $sel_trees = prepare_sth($dbh, "SELECT name FROM tree");
    my $sel_root = prepare_sth($dbh, 
                               "SELECT n.node_id, n.label FROM tree t, node n "
                               ."WHERE t.node_id = n.node_id AND t.name = ?");
    my $sel_chld = prepare_sth($dbh, 
                               "SELECT n.node_id, n.label, e.edge_id "
                               ."FROM node n, edge e "
                               ."WHERE n.node_id = e.child_node_id "
                               ."AND e.parent_node_id = ?");
    my $sel_attrs = prepare_sth($dbh,
                                "SELECT t.name, eav.value "
                                ."FROM term t, edge_attribute_value eav "
                                ."WHERE t.term_id = eav.term_id "
                                ."AND eav.edge_id = ?");

    # If the trees variable was not passed to the subfunction
    # select the names of all of the trees in the database
    # and load the names to the @trees subfunction
    if (! (@trees && $trees[0])) {
        @trees = ();
        execute_sth($sel_trees);
        while (my $row = $sel_trees->fetchrow_arrayref) {
            push(@trees,$row->[0]);
        }
    }

    # For each tree in the array get the root node
    foreach my $tree (@trees) {
        execute_sth($sel_root, $tree);
        my $root = $sel_root->fetchrow_arrayref;
        if ($root) {
            print ">$tree ";
        } else {
            print STDERR "no tree with name '$tree'\n";
            next;
        }
        &load_tree_nodes($sel_chld,$root,$sel_attrs);
    } # End of for each tree

} # End of print_trees subfunction


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


=head1 HISTORY

Started: 06/18/2007

Updated: 06/19/2007

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
