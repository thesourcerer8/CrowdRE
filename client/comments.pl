#!/usr/bin/perl -w
use strict;

foreach my $f (<goodlogs/*.log>)
{
  open IN,"<$f";
  while(<IN>)
  {
    s/; 0x//;
    s/; 00//;
    s/;;/;/;
    if(m/^(0x\w+).*?;\s*(.*)/)
    {
      print "$1 $2\n";
      open OUT,">comment/comment$1";
      print OUT $2;
      close OUT;
    }
  }
  close IN;
}
