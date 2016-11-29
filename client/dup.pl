#!/usr/bin/perl -w
use Digest::MD5 qw(md5_hex);

sub handle($)
{
  open IN,"<$_[0]";
  my $data="";
  read IN,$data,1024;
  my $digest = md5_hex($data); 
  my $size=sprintf("%8s",-s $_[0]);
  print $digest." ".$size." ".$_[0]."\n";
}

handle($_) foreach(<*.log>);
handle($_) foreach(<*/*.log>);
handle($_) foreach(<*/*/*.log>);
handle($_) foreach(<*/*/*/*.log>);

