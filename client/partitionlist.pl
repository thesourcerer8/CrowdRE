#!/usr/bin/perl -w

my $pos=0;

my $start=0;
my $size=0;

sub sayBytes($)
{
  return int($_[0]/1024/1024/1024/1024)." TB" if($_[0]>1024*1024*1024*1024);
  return int($_[0]/1024/1024/1024)." GB" if($_[0]>1024*1024*1024);
  return int($_[0]/1024/1024)." MB" if($_[0]>1024*1024);
  return int($_[0]/1024)." KB" if($_[0]>1024);
  return int($_[0])." B";
}


while($pos<0xFFFFFFFF)
{
  my $posx=sprintf("%X",$pos);
  my $poslx=sprintf("%08X",$pos);
  my $s=-s "ssdgood/mem0x$posx" || 0;

  if($s && !$size)
  {
    $start=$poslx;
  }
  
  if(!$s && $size)
  {
    my $short=$size/0x10000;
	my $sizex=sprintf("%08X",$size);
	my $bytes=sayBytes($size);
    print "Section: start=$start size=$sizex blocks=$short   $bytes\n";
    $size=0;
  }
  $size+=$s;

  $pos+=0x10000;
}