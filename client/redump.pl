#!/usr/bin/perl -w
use strict;

my $adr=0;

# This tool generates dump commands for reachable pages of an existing dump directry, to re-dump only reachable pages and skipping non-reachable pages

  while($adr<0x100000000)
  {
    my $adrx=sprintf("%X",$adr);
    if(-s "ssdgood/mem0x$adrx")
    {
      print "dump_image ssdbad/mem0x$adrx 0x$adrx 0x10000\n";
    }
    $adr+=0x10000;
  }


