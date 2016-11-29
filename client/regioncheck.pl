#!/usr/bin/perl -w
use strict;

  my $pos=0;
  my $start=0;
  my $size=0;
  print "sub checkmemrange(\$)\n";
  print "{\n";
  print "  my \$pos=\$_[0];\n";
  while($pos<0xFFFF0000)
  {
    #print "$pos\n";
    my $posx=sprintf("%X",$pos);
    my $poslx=sprintf("%08X",$pos);
    my $s=-s "ssdgood/mem0x$posx" || 0;
	#print "$pos $s\n";
  
    if($s && !$size)
    {
      $start=$poslx;
    }
    
    if(!$s && $size)
    {
      print "  return 1 if(\$pos>=0x$start && \$pos <0x$poslx);\n";
	  $size=0;
    }
	$size+=$s;
	$pos+=0x10000;
  }
  print "  return 0;\n";
  print "}\n";