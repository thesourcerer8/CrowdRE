#!/usr/bin/perl -w
use strict;
use IO::Socket::INET;

my $sock=IO::Socket::INET->new(PeerAddr=>"localhost:4444");

my $head=<$sock>;

open IN,"<cortexr4regs.txt";
open OUT,">cortexr4regs.html";
print OUT "<html><body>";
my @lines=<IN>;

sub getlines($)
{
  my @arr=();
  print "Getlines($_[0])...\n";
  foreach(1 .. $_[0])
  {
    my $a=<$sock>;
    $a=~s/\0//gs;
    push @arr,$a;
  }
  print @arr;
  if($arr[0]!~m/>/)
  {
    print "\n\nOut of sync?!?\n\n";
    exit;
  }
  print "Getlines done \n";
  return @arr;
}



my @cpus=("mex1"); #,"mex2","mex3");

our %results=();
our $state="";
foreach(@lines)
{ 
  if(m/MRC p15, (\d+), <Rd>, c(\d+), c(\d+), (\d+)\s+[;:]\s*(.*)/)
  {
    my $reg="15 $1 $2 $3 $4";

	foreach my $cpu(@cpus)
	{
	  print $sock "$cpu arm mrc $reg\n";
          #print OUT "arm mrc $reg<br/>\n";
	  my @res=getlines(2);
	  if($res[1]=~m/(\d+)/)
	  {
  	    $results{$cpu}{$state}=$1; 
	    # Since the MRC command is always after the documentation, we remember the result to the previous MRC command :-( Strange, but it works :-)
	    # The first result is assigned to $results{""}
      }
	}
	$state=$reg; # 
  }
}

sub printDecHex($)
{
  my $v=$_[0];
  my $h=sprintf("%X",$v);
  return $v eq $h ? "$v": "$v(0x$h)";
}

sub displayall($$$)
{
  my $a=$_[0];
  my $b=$_[1];
  my $vr=undef;
  my $showall=0;
  my $all="";
  my $one="";
  foreach my $cpu(@cpus)
  {
    print "state:$state a:$a b:$b\n";
    my $v=($results{$cpu}{$state} >> $b) & ((2**($a-$b)) - 1);
    if(defined($vr))
    {
      if($v ne $vr)
      {
        $showall=1;
      }
    }
    else
    {
      $vr=$v;
    }
    $all.="$cpu:".printDecHex($v)." ";
    $one=printDecHex($v)." ";
  }
  return $showall?$all:$one;
}


$state="";
foreach(@lines)
{
  my $bgcolor="#e0ffe0";
  my $o="";
  if(m/^\s*\[(\d+):\s*(\d+)]\s+(.*)$/)
  {
	;
	$o="Value: <b>".displayall($1,$2,$state)."</b> ";
  }
  elsif(m/^\s*\[(\d+)]\s+(.*)$/)
  {
	$o="Value: <b>".displayall($1,$1,$state)."</b> ";
  }
  elsif(m/MRC p15, (\d+), <Rd>, c(\d+), c(\d+), (\d+)\s+[;:]\s*(.*)/)
  {
    $state="15 $1 $2 $3 $4";
  }
  elsif(m/^\s*(0?[xb]?\w+) = (.*)/)
  {
  }
  elsif(m/MRC/)
  {
    #print "Could not parse MRC: $_\n";
  }
  elsif(m/----------/)
  {
    $bgcolor="#ffffff";
  }
  else
  {
    $bgcolor="#ffffff";
  }
  print OUT "<div style=\"background-color:$bgcolor; overflow:hidden;\">$o$_</div>";
}

close OUT;
