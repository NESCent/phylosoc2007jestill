#!/usr/bin/perl -w
# JCE: 06/07/2007
# Short script based on code at:
# http://www.bioperl.org/wiki/HOWTO:Trees 
use Bio::TreeIO;
use Bio::Tree::RandomFactory;
# initialize a TreeIO writer to output the trees as we create them
#$out = Bio::TreeIO->new(-format => 'newick',
#			-file   => ">RandomTree.tre");

$out = Bio::TreeIO->new(-format => 'nhx',
			-file   => ">RandomTree.nhx");

my @listoftaxa = qw(A B C D E F G H I J K L M N O P Q R S T U V W X Y Z);
my $factory = new Bio::Tree::RandomFactory(-taxa => \@listoftaxa);

# Generate a single random tree
$out->write_tree($factory->next_tree);
exit;
