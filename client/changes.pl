#!/usr/bin/perl -w
use strict;

my $addr=0;

sub readfile($)
{
  if(open(RIN,"<$_[0]"))
  {
    undef $/;
    my $d=<RIN>;
    close RIN;
    return $d;
  }
  return "";
}

while($addr<0xffffffff)
{
  my $haddr=sprintf("%X",$addr);
  my $good1=readfile("ssdgood/mem0x$haddr");
  my $good2=readfile("ssdgood2/mem0x$haddr");
  my @ent=();
  $ent[0]=`ent ssdbad/mem0x$haddr`;
  $ent[1]=`ent ssdgood/mem0x$haddr`;
  $ent[2]=`ent ssdgood2/mem0x$haddr`;
  my $entres="";
  foreach(@ent)
  {
    my $ent=0;
    #print "$_\n";
    $ent=$1 if($_=~m/Entropy = (\d+\.?\d*)/s);
    $entres.="$ent ";
  }
  if(length($good1) && $good1 eq $good2)
  {
    print "0x$haddr $entres IDENTIC\n"; 
  }  
  elsif(!length($good1))
  {
    print "0x$haddr $entres EMPTY\n";
  }
  elsif(length($good1) != length($good2))
  {
    print "0x$haddr $entres LENGTHDIFF\n"; 
  }
  else
  {
    my $changes=0;
    foreach(0 .. length($good1)-1)
    {
      $changes++ if(substr($good1,$_,1) ne substr($good2,$_,1));
    }
    print "0x$haddr $entres DIFFER $changes\n";
  }
  $addr+=0x10000;
}
