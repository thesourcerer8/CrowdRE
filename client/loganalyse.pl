#!/usr/bin/perl -w
use strict;

# Usage:
# perl loganalyse.pl |sort |uniq >loganalyse.txt

our %r=();
our %w=();
our %x=();
our %bx=();
our %br=();
our %bw=();

my %seen=();

mkdir "logindexnew";

foreach(<logindexnew/*>)
{
  unlink $_;
}

sub annotatemem($$$$$$$$)
{
  my ($addr,$rwx,$mode,$core,$thumbstate,$pc,$line,$f)=@_;
  my $block=sprintf("0x%08X",hex($addr)&0xffff0000);
  my $data="$block,$addr,$rwx,$mode,$core,$thumbstate,$pc";
  print "$data\n" if(!defined($seen{$data}));
  $seen{$data}=1;
  $x{$addr}{$mode}{$core}=1;
  $bx{$block}{$core}{$mode}=1;
  if(open OUT,">>logindexnew/$addr")
  {
    my $g=$f; $g=~s/^goodlogs\///;
    print OUT "$g,$line";
    close OUT;
  }
}


foreach my $f(<goodlogs/*.log>)
{
  my $core="mex1";
  $core=$1 if($f=~m/(mex\d)/);
  
  if(open(IN,"<$f"))
  {
    our $state="";
    our $mode="";
    
    while(<IN>)
    {
      if(m/starting/)
      {
         # Reinitialize where necessary
         $state="";
         $mode="";
      }
      elsif(m/target halted in (\w+) state due to (\w+-?\w*), current mode: (\w+)/)
      {
         $state=$1;
         $mode=$3;
      }
      elsif(m/^cpsr: (0x\w{8}) pc: (0x\w{8})/)
      {
         my $cpsr=$1; my $thumb=hex($cpsr)&(1<<5); my $thumbstate=$thumb?"Thumb":"ARM";
         if($thumbstate ne $state)
         {
           print "mode problem: $f $cpsr $state $thumbstate\n";
         }
         my $pc=$2;
         annotatemem($pc,"x",$mode,$core,$thumbstate,$pc,$_,$f);
      }
      #0x00010698->0x00010692 Thumb Supervisor 0x00010698  0xd3fb       BCC 0x00010692
      #ERROR: 0x00010692->0x00010694 Thumb Supervisor 0x00010692  0x1c49       ADDS
      #     r1, r1, #1 r1:0x00000052=>0x00000053 r1:0x00000052=>0x00000053
      elsif(m/(0x\w+)->(0x\w+) (\w+) (\w+-?\w*) (0x\w+)\s+(0x\w+)\s+(\S+) (.*)/)
      {
        my $addr=$1;
        my $r=$8;
        my $mode=$4;
        annotatemem($addr,"x",$4,$core,$3,$addr,$_,$f);
        while($r=~s/r\d+:(0x\w+)=>(0x\w+)//)
        {
          # This is a register, not memory
          #annotatemem($1,"w",$4,$core,$3,$addr,$_,$f);
        }
        while($r=~s/\[(0x\w+)\]:\w+=>\w+//)
        {
          annotatemem($1,"w",$mode,$core,"data",$addr,$_,$f);
        }
        while($r=~s/\[(0x\w+)\]=\w+//)
        {
          annotatemem($1,"r",$mode,$core,"data",$addr,$_,$f);
        }
      }
      elsif(m/(0x\w+)->(0x\w+) (\w+) (\w+-?\w*) (0x\w+)\s+/)
      {
        annotatemem($1,"x",$4,$core,$3,$1,$_,$f);
      }
      elsif(m/^\s*$/)
      {
      }
      elsif(m/\((\d+)\) (\w+) \(\/32\): (0x\w+)( \(dirty\))?/) # Register dump
      {
      }
      elsif(m/\((\d+)\) (\w+) \(\/32\)/) # Register dump
      {
      }
      elsif(m/^(resume halt|> step|mex\d?: target state: halted|\s*===== ARM registers|D-Cache: disabled, I-Cache: disabled|Getlines...)/)
      {
      }
      else
      {
        #print "ERROR: $f $_\n";
      }
  
  
    }
    close IN;
  }
}

rename "logindex","logindexold";
rename "logindexnew","logindex";
system "rm -rf logindexold";
