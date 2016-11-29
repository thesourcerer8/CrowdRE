#!/usr/bin/perl -w
use strict;
use IO::Socket::INET;

my $sock=IO::Socket::INET->new(PeerAddr=>"localhost:4444");

print $sock "targets mex1\n";
print $sock "halt\n";

sub mydump($)
{
  my $addr=sprintf("0x%08X",$_[0]);
  print $sock "dump_image fbd/fbd$ARGV[0]$addr $addr 256\n";
}

mydump(0x20500000);
mydump(0x20501000);
mydump(0x20501200);
mydump(0x20504000);
mydump(0x0001FEA0);
mydump(0x0000D1F8);
mydump(0x0080FE50);
mydump(0x00803400);
mydump(0x00800000);
mydump(0x0081C900);
mydump(0x10050000);
mydump(0x1004F000);
mydump(0x0000aee2);
mydump(0x80000024);
mydump(0x0081C63C);
mydump(0x20506000);
mydump(0x10010060);
mydump(0x0081C674);


sleep(10);


