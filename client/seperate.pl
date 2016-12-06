#!/usr/bin/perl -w
use strict;

my %fn=();
my %comm=();
open IN,"<radare.txt";
while(<IN>)
{
  if(m/af (\w+) \@0x0*(\w+)/)
  {
    $fn{$2}.=$1;
    #print "sub_$2 [label=\"$1\"]\n";
  }
  if(m/"CC (.*)" \@0x0*(\w+)/)
  {
    $comm{uc $2}.=$1;
    $fn{uc $2}=$1 if(!defined($fn{$2}));
    #print "comm sub_$2 [label=\"$1\"]\n";
 
  }
}
close IN;



mkdir "out";

open IN,"<upload.c";
open OUT,">out/head.c";
my $func=0;
my %graph=();
while(<IN>)
{
  if(m/\/\/----- \((\w+)\) ----------------/)
  {
    $func=$1; $func=~s/^0+//;
    close OUT;
    open OUT,">out/$func.c";
  }
  elsif(m/sub_(\w+)\([^\)]*\) \/\/ (\w+)\s*$/)
  {
    $fn{$1}.=$2;    
    print "Found function name: $2\n";
  } 
  elsif(m/(sub_\w+)\(/)
  {
    my $f=$1;
    $graph{"sub_".$func}{$f}++ if($func && "sub_".$func ne $f);
  }
  print OUT $_;

}
close IN;
close OUT;


open GRAPH,">graph.dot";
print GRAPH "graph {\n";

my %cellseen=();
sub cell($)
{
  my $d=$_[0]; $d=~s/^sub_//;
  if(!defined($cellseen{$d}) && defined($fn{$d}))
  {
    print GRAPH "sub_$d [label=\"".$fn{$d}."\"]\n";
  }
  $cellseen{$d}=1; 
}

foreach my $a(sort keys %graph)
{
  foreach my $b(sort keys %{$graph{$a}})
  {
    cell($a);
    cell($b);
    print GRAPH "$a -- $b\n";
  }
}


print GRAPH "}\n";
system "dot graph.dot -Tsvg -o graph.svg";
