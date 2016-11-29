#!/usr/bin/perl -w
use strict;

open IN,"<".($ARGV[0]||"debugmex2.log");
my $count=0;
my @isstart=(1);
my @nextv=();
my @liste=();
my %start=();
my @thisv=();
my @startof=();
my $state=0;
while(<IN>)
{
  if(m/(0x\w{8})->(0x\w{8})/)
  {
    $liste[$count]=$_;
    $start{$1}{$count}=$count; 
    $thisv[$count]=$1;
    $nextv[$count]=$2;
    $startof[$count]=$state;
    #print "$count $1 $2\n";
    $count++;
  }
  elsif(m/Memory access \w+ out of/)
  {
  }
  else
  {
    $isstart[$count]=1;
    $state=$count;
  }
}


sub fisher_yates_shuffle
{
    my $array = shift;
    my $i = @$array;
    while ( --$i )
    {
        my $j = int rand( $i+1 );
        @$array[$i,$j] = @$array[$j,$i];
    }
}

sub isgood($$)
{
  my $good=$_[0];
  my $try=$_[0];

  my $i=0;
  while(!$isstart[$try-$i])
  {
    if($thisv[$try-$i] ne $thisv[$good-$i])
    {
      #print "$try is not good\n";
      return 0;
    }
    $i++;
  }
  #print "$try is good\n";
  return 1;
}


my $pos=0;
my $ende=0;
my $next="";
my @res=();
my %seen=();
while($pos<scalar(@liste))
{
  print "$pos: ";
  if($pos && $isstart[$pos])
  {
    #print "We found an end ($pos), now we have to search for the next ($nextv[$pos-1])\n"; 
    my @tries=keys(%{$start{$nextv[$pos-1]}});
    if(!scalar(@tries))
    {
      print "We never traced that address. Perhaps we need more samples (@tries)?\n";
      exit;
    }
    fisher_yates_shuffle( \@tries);
    #print "We can try at the following locations: @tries\n";
    my $found=0;
    while(!$found && scalar(@tries))
    {
      my $try=pop(@tries);
      next if(defined($seen{$startof[$try]}));
      $found=isgood($pos-1,$try-1);
      $pos=$try-1 if($found);
    }
    if(!$found)
    {
      print "We are at the end. No more matching sequences found. We might want to try backwards now.\n";
      exit;
    }
  }
  else
  {
    print $liste[$pos];
    push @res,$liste[$pos]; 
    $seen{$startof[$pos]}=1;
  }

  $pos++;
}

