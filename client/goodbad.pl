#!/usr/bin/perl -w

my $check="ssdbad";

sub loadMemory($$$)
{
  my $pos=$_[1]&0xFFFF0000;
  my $mem="";
  
  while($pos<($_[1]+$_[2]+0x20000))
  {
    if(open INM,"<$_[0]/mem0x".sprintf("%X",$pos))
	{
	  undef $/;
	  $mem.=<INM>;
	  close INM;
	}
	$pos+=0x10000;
  }
  return substr($mem,($_[1]&0xFFFF),$_[2]);
}

my $pos=0;

while($pos<0xFFFFFFFF)
{
  my $posx=sprintf("0x%X",$pos);
  if(-s "ssdgood/mem$posx")
  {
    my $goodsize=-s "ssdgood/mem$posx";
    my $badsize=-s "ssdbad/mem$posx";
	if($goodsize==$badsize)
	{
      my $good= loadMemory("ssdgood",$pos,0x10000);
      my $bad= loadMemory("ssdbad",$pos,0x10000);
      my $ident=0;
	  my @ent=();
      foreach(0 .. 0xffff)
      {
        $ident++ if(substr($good,$_,1)eq substr($bad,$_,1));
		$ent[unpack("C",substr($good,$_,1))]++;
      }
      print "$posx $ident ".int($ident*100/0x10000)."%\n";
    }
    else
    {
      print "$posx different sizes: $goodsize $badsize\n";
    }
  }
  $pos+=0x10000;
}