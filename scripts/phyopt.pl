#!/usr/bin/perl -w
#-----------------------------------------------------------+
#                                                           |
# phyopt.pl - Optimize phylodb database.                    |
#                                                           |
#-----------------------------------------------------------+
#                                                           |
#  AUTHOR: James C. Estill                                  |
# CONTACT: JamesEstill_at_gmail.com                         |
# STARTED: 07/04/2007                                       |
# UPDATED: 07/20/2007                                       |
#                                                           |
# DESCRIPTION:                                              | 
#  Optimize a PhyloDB. Add left and right index values.     |
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
# - Add taxa to the biosql database and add taxa information
#   from the tree to the PhyloDB node table. This would required
#   using the taxon_id field in the node table
# - Add edge_attribute data when available
 
=head1 NAME 

phyopt.pl - Optimize trees in a PhyloDB database

=head1 SYNOPSIS

  Usage: PhyImport.pl
        --dsn        # The DSN string the database to connect to
                     # Must conform to:
                     # 'DBI:mysql:database=biosql;host=localhost' 
        --dbuser     # User name to connect with
        --dbpass     # Password to connect with
        --dbname     # Name of database to use
        --driver     # "mysql", "Pg", "Oracle" (default "mysql")
        --host       # optional: host to connect with
        --help       # Print this help message
        --quiet      # Run the program in quiet mode.
        --format     # "newick", "nexus" (default "newick")
        --tree       # Name of the tree to optimize.
                     # Otherwise the entire db is optimized.

=head1 DESCRIPTION

Optimize trees in a PhyloDB database.

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

=item -t, --tree

Name of the tree that will be optimized.

=back

=head1 AUTHORS

Hilmar Lapp <hlapp at gmx.net>

James C. Estill E<lt>JamesEstill at gmail.comE<gt>

=head1 Contributors

William Piel <william.piel at yale.edu>

=cut

#-----------------------------+
# INCLUDES                    |
#-----------------------------+
use strict;
use DBI;
use Getopt::Long;
use constant LOG_CHUNK => 10000;

#-----------------------------+
# VARIABLE SCOPE              |
#-----------------------------+
my $ver = "Dev 07/20/2007";    #

my $usrname = $ENV{DBI_USER};  # User name to connect to database
my $pass = $ENV{DBI_PASSWORD}; # Password to connect to database
my $dsn = $ENV{DBI_DSN};       # DSN for database connection
my $infile;                    # Full path to the input file to parse
my $format = 'newick';         # Data format used in infile
my $db;                        # Database name (ie. biosql)
my $host;                      # Database host (ie. localhost)
my $driver;                    # Database driver (ie. mysql)
my $sqldir;                    # Directory that contains the sql to run
                               # to create the tables.
my $quiet = 0;                 # Run the program in quiet mode
                               # will not prompt for command line options
my $tree_name;                  # The name of the tree
                               # For files with multiple trees, this may
                               # be used as a base name to name the trees with
my $statement;                 # Var to hold SQL statement string
#my $sth;                       # Statement handle for SQL statement object
my @trees = ();                # Array holding the names of the trees that will
                               # be exported
my $verbose;                   # Boolean, but chatty or not
my $tree;                      # This is what H. Lapp used
my $show_help = 0;             # Display help
my $show_man = 0;              # Show the man page via perldoc
my $show_usage = 0;            # Show the basic usage for the program
my $show_version = 0;          # Show the program version

#-----------------------------+
# COMMAND LINE OPTIONS        |
#-----------------------------+
my $ok = GetOptions("d|dsn=s"    => \$dsn,
                    "u|dbuser=s" => \$usrname,
#                    "i|infile=s" => \$infile,
#                    "f|format=s" => \$format,
                    "p|dbpass=s" => \$pass,
                    "v|verbose"  => \$verbose,
		    "s|sqldir=s" => \$sqldir,
		    "driver=s"   => \$driver,
		    "dbname=s"   => \$db,
		    "host=s"     => \$host,
		    "t|tree=s"   => \$tree_name,
		    "q|quiet"    => \$quiet,
		    "version"    => \$show_version,
		    "man"        => \$show_man,
		    "usage"      => \$show_usage,
		    "h|help"     => \$show_help,
		    );

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
# SQL STATEMENTS              |
#-----------------------------+
# As taken from tree-precompute
my $sel_children = prepare_sth(
    $dbh, "SELECT child_node_id FROM edge WHERE parent_node_id = ?");  
my $upd_nestedSet  = prepare_sth(
    $dbh, "UPDATE node SET left_idx = ?, right_idx = ? WHERE node_id = ?");
my $reset_nestedSet = prepare_sth(
    $dbh, "UPDATE node SET left_idx = null, right_idx = null ".
    "WHERE tree_id =?");
#my $sel_trees = 
#    "SELECT t.name, t.node_id, t.tree_id FROM tree t, biodatabase db "
#    ."WHERE db.biodatabase_id = t.biodatabase_id";

# Jame changed this to the following
my $sel_trees = 
    "SELECT name, node_id, tree_id FROM tree";

#-----------------------------+
# EXIT HANDLER                |
#-----------------------------+
#END {
#    &end_work($dbh);
#}


#-----------------------------+
# GET THE TREES TO PROCESS    |
#-----------------------------+
# TODO: Check to see if the tree does exist in the database
#        throw error message if it does not
#       This also needed for phyexport.pl

my @bind_params = ();
#if (defined($tree)) {
if (defined($tree_name)) {
    $sel_trees .= " AND t.name = ?";
    #push(@bind_params, $tree);
    push(@bind_params, $tree_name);
}

# This will not work with Jamie's implementation
#if (defined($namespace)) {
#    $sel_trees .= " AND db.name = ?";
#    push(@bind_params, $namespace);
#}

my $sth = prepare_sth($dbh, $sel_trees);
execute_sth($sth, @bind_params);

while(my $row = $sth->fetchrow_arrayref) {
    my ($tree_name, $root_id, $tree_id) = @$row;

    print STDERR "Computing nested set values for tree $tree_name...\n";
    print STDERR "\tresetting existing values\n" if $verbose;

    # we need to reset the values to null first to prevent any
    # possible unique key violations when updating on a tree that has
    # them already

    execute_sth($reset_nestedSet, $tree_id);
    # Jamie added the commit here

    print STDERR "\tcomputing new values:\n" if $verbose;
    # recursively traverse the tree, depth-first, filling in the value
    # along the way
    handle_progress(0) if $verbose; # initialize
    walktree($root_id);
    # Jamie added commit here
    $dbh->commit;

    handle_progress(LOG_CHUNK, 1) if $verbose; # final tally
    print STDERR "Computing transitive closure for tree $tree_name...\n";
    # transitive closure for the given tree; this will delete existing
    # paths first
    compute_tc($dbh, $tree_id);
    print STDERR "Done.\n";
    $dbh->commit;
}

# End of program
$sth->finish();
$dbh->disconnect();
print "\n$0 has finished.\n";
exit;

#-----------------------------------------------------------+
# SUBFUNCTIONS                                              |
#-----------------------------------------------------------+

sub walktree {
# Taken from tree-precompute    
    my $id = shift;
    my $left = shift || 1;
    my $right = $left+1; # default for leaf

    execute_sth($sel_children,$id);
    
    my @children = ();
    while (my $row = $sel_children->fetchrow_arrayref) {
        push(@children,$row->[0]);
    }
    foreach my $child (@children) {
        $right = walktree($child, $right);
        $right++;
    }
    execute_sth($upd_nestedSet, $left, $right, $id);
    handle_progress(LOG_CHUNK) if $verbose;
    return $right;
}

sub handle_progress{
    my $chunk = shift;
    my $final = shift;
    our $_time = time() if $chunk == 0;
    our $_n = 0 if $chunk == 0;
    our $_last_n = 0 if $chunk == 0;
    return if $chunk == 0;
    $_n++ unless $final;
    if ($final || (($_n-$chunk) >= $_last_n)) {
	my $elapsed = time() - $_time;
        my $fmt = "\t%d done (in %d secs, %4.1f rows/s)\n";
        printf STDERR $fmt, $_n, $elapsed, ($_n-$_last_n)/($elapsed||1);
        $_time = time() if $elapsed;
        $_last_n = $_n;
    }
}


sub compute_tc {
# Taken from tree-precompute
#    my ($dbh, $tree) = 
    my $dbh = shift;
    my $tree = shift;
    my $del_sql =
        "DELETE FROM node_path WHERE child_node_id IN ("
        ."SELECT node_id FROM node WHERE tree_id = ?)";
    my $zero_sql = 
        "INSERT INTO node_path (child_node_id, parent_node_id, distance)"
        ." SELECT n.node_id, n.node_id, 0 FROM node n WHERE n.tree_id = ?";
    my $init_sql = 
        "INSERT INTO node_path (child_node_id, parent_node_id, path, distance)"
        ." SELECT e.child_node_id, e.parent_node_id, n.left_idx, 1"
        ." FROM edge e, node n"
        ." WHERE e.child_node_id = n.node_id AND n.tree_id = ?";
    my $path_sql =
        "INSERT INTO node_path (child_node_id, parent_node_id, path, distance)"
        ." SELECT e.child_node_id, p.parent_node_id,"
        ." p.path||'.'||n.left_idx, p.distance+1"
        ." FROM node_path p, edge e, node n"
        ." WHERE p.child_node_id = e.parent_node_id"
        ." AND n.node_id = e.child_node_id AND n.tree_id = ?"
        ." AND p.distance = ?";
    print STDERR "\tdeleting existing transitive closure\n" if $verbose;
    my $sth = prepare_sth($dbh,$del_sql);
    execute_sth($sth, $tree);
    print STDERR "\tcreating zero length paths\n" if $verbose;
    $sth = prepare_sth($dbh,$zero_sql);
    execute_sth($sth,$tree);
    print STDERR "\tcreating paths with length=1\n" if $verbose;
    $sth = prepare_sth($dbh,$init_sql);
    execute_sth($sth,$tree);
    $sth = prepare_sth($dbh,$path_sql);
    my $dist = 1;
    my $rv = 1;
    while ($rv > 0) {
        print STDERR "\textending paths with length=$dist\n" if $verbose;
        $rv = execute_sth($sth, $tree, $dist);
        $dist++;
    }
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
	"  phyopt.pl -i InFile -o OutFile";
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

Started: 07/04/2007

Updated: 07/20/2007

=cut

#-----------------------------------------------------------+
# HISTORY                                                   |
#-----------------------------------------------------------+
# 07/04/2007 - JCE
# - Program started
# - Started the add_lr_id subfunction to add the left and
#   right ids
# 
# 07/05/2007 - JCE
# - Had to upgrade MySQL from 4.0 to 4.1 to use nested
#   SQL statements. This was needed to get the transitive
#   closure to work.
# - Added verbose to command line to make work with
#   tree-precompute from H. Lapp
# 
# 07/20/2007
# - Added help, man, version, and usage to command line
#   options.
# - Added print_help subfunction
