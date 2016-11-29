#!/usr/bin/perl -w
use strict;
use IO::Socket::INET;

unlink "done";

my $sock=IO::Socket::INET->new(PeerAddr=>"localhost:4444");

my $line=<$sock>;
print $line;

my $core="mex1";
$core=$1 if($ARGV[0]=~m/(mex\d)/);


open OUT,">>debug$core.log";
print OUT "\nstarting $core\n";


my $ofh=select OUT;
$|=1;
select STDOUT;

our %skippoints=();
our %breakpoints=();

sub checkmemrange($)
{
  my $pos=$_[0];
  return 0 if($pos==0x000C0588);
  return 0 if($pos==0x000C0580);
  return 1 if($pos>=0x00000000 && $pos <0x00020000);
  return 1 if($pos>=0x00800000 && $pos <0x01000000);
  return 1 if($pos>=0x10010000 && $pos <0x10030000);
  return 1 if($pos>=0x10040000 && $pos <0x10060000);
  return 1 if($pos>=0x10100000 && $pos <0x10200000);
  return 1 if($pos>=0x20000000 && $pos <0x20600000);
  return 1 if($pos>=0x40000000 && $pos <0x43000000);
  return 1 if($pos>=0x44000000 && $pos <0x47000000);
  return 1 if($pos>=0x48000000 && $pos <0x4B000000);
  return 1 if($pos>=0x80000000 && $pos <0xA0000000);
  return 0;
}


foreach my $f(<goodlogs/*>)
{
  open LIN,"<$f";
  #print "Reading $f\n";
  while(<LIN>)
  {
    if(m/^(0x\w+).*SKIP\((0x\w+)\)/)
    {
      $skippoints{$1}=$2;
      print "$f: We will set a Breakpoint on $1 to skip to $2\n";
    }
    if(m/^(0x\w+).*BREAKPOINT/)
    {
      $breakpoints{$1}=1;
      print "$f: We will set a Breakpoint on $1 immediately\n";
    }


  }
  close LIN;
}

our $isa="";
our $mode="";
our $pc="";

sub getlines($)
{
  my @arr=();
  print "Getlines($_[0])...\n";
  foreach(1 .. $_[0])
  {
    my $a=<$sock>;
    if($a=~m/embedded:startup.tcl:21: Error: error reading target/)
    {
      $a=<$sock>;
    }
    $a=~s/\0//gs;
    push @arr,$a;
    if($a=~m/pc: (0x\w+)/)
    {
      #print OUT $a;
      $pc=$1;
    }
    if($a=~m/target halted in (\w+) state.*current mode: (\w+)/)
    {
      if($isa ne $1 || $mode ne $2)
      {
        $isa=$1;
        $mode=$2;
        #print OUT $a;
      }
    }

  }
  print @arr;
  if($arr[0]!~m/>/)
  {
    print OUT "\nOut of sync?!?\n\n";
    print "\n\nOut of sync?!?\n\n";
    exit;
  }
  if(-f "done")
  {
    print OUT "Done: Workload finished.\n";
    print "Done: Workload finished.\n";
    exit;
  }
  print "Getlines done \n";
  return @arr;
}

my $adr=0x80000000;

unlink "done";
#system "bash workload_ssdread.sh &";
#sleep(1);

print $sock "targets ".($core||"mex1")."\n";
my $lines;
$lines=getlines(1);

# Now we loook whether the core is running and we halt it if it is still running
print $sock "targets\n";
my @targets=getlines(6);
if(join(";",@targets)=~m/$core\s+cortex_r4\s+little\s+\S+\s+(halted|running)/)
{
  print "$1\n";
  if($1 eq "running")
  {
    print $sock "halt\n";
    getlines(5);
  }

}

sub serialnumber($)
{
  my $d=$_[0];
  $d=~s/^\0?0x40825088: //;
  $d=~s/ //g;
  my  $serial="";
  foreach(0..3)
  {
    $serial.=pack("C",hex(substr($d,$_*8+4,2)));
    $serial.=pack("C",hex(substr($d,$_*8+6,2)));
    $serial.=pack("C",hex(substr($d,$_*8+0,2)));
    $serial.=pack("C",hex(substr($d,$_*8+2,2)));
  }
  my $s=substr($serial,0,15); 
  $s=~s/\x00//g;
  return $s;
}

#print $sock "$core mdw 0x40825088 4\n";
#my @mdw=getlines(2);
#if($mdw[1]=~m/0x40825088/)
#{
#  print OUT "SERIAL NUMBER=".serialnumber($mdw[1])."\n";
#  print "SERIAL NUMBER=".serialnumber($mdw[1])."\n";
#}
#else
#{
#  $mdw[1]=<$sock>;
#  print OUT "SERIAL NUMBER=".serialnumber($mdw[1])."\n";
#  print "SERIAL NUMBER=".serialnumber($mdw[1])."\n";
#}


print $sock "reg\n";
print OUT getlines(44);
foreach(0 .. 41)
{
  print $sock "reg $_\n";
  print OUT getlines(2);
}

my $counter=0;
while(1)
{
  print $sock "poll\n";
  $lines=getlines(7);
  if($mode eq "Abort")
  {
    $lines.=<$sock>;
    $lines.=<$sock>;
  }

  print "Hit? $pc\n";
  if(defined($skippoints{$pc}))
  {
    print "Hitting skip point!\n";
    print $sock "bp $skippoints{$pc} 1 hw\n";
    $lines=getlines(2);
    print $sock "resume\n";
    $lines=getlines(5);
    next;
  }

  print $sock "arm disassemble $pc 1 ".($isa eq "Thumb"?"thumb":"")."\n";
  my @lines=getlines(2);
  my $disasm=$lines[1];
  $disasm=~s/[\r\n\0]//sg;

  my $dadr=undef;
  my $dvalue="";
  my $regs=$lines[1];
  my @regs=();
  my %rval=();
  # Parsing relevant registers
  if($disasm=~m/(UNDEFINED OPCODE|UNDEFINED INSTRUCTION)/)
  {
    $regs.="r$_ " foreach(0 .. 40);
  }
  my %regseen=();
  while($regs=~s/r(\d\d?)//)
  {
    my $r=$1;
    next if(defined($regseen{$r}));
    $regseen{$r}=1;
    push @regs,$r;
    print $sock "reg $r\n";
    my @reglines=getlines(2);
    print "regline: $reglines[1]";
    $rval{"r$r"}=$1 if($reglines[1]=~m/(0x\w+)/);
  }
  while($regs=~s/(sp)//)
  {
    my $r=$1;
    next if(defined($regseen{$r}));
    $regseen{$r}=1;
    push @regs,$r;
    print $sock "reg $r\n";
    my @reglines=getlines(2);
    print "regline: $reglines[1]";
    $rval{"$r"}=$1 if($reglines[1]=~m/(0x\w+)/);
  }
  $rval{'pc'}=$pc;

  if($lines[1]=~m/\[(r\d+|pc)(, #(\w+))?\]/)
  {
    # Memory access detected:
    $dadr=$rval{$1};
    if(defined($2))
    {
      $dadr=sprintf("0x%08X",hex($dadr)+hex($3));
    }
    if(checkmemrange(hex($dadr)))
    {
      print $sock "$core mdw $dadr\n";
      my @dlines=getlines(2);
      if($dlines[1]=~m/(0x\w+): (\w+)/)
      {
        $dvalue=$2;
        print "Data value at $adr was $2\n";
      }
      if($dlines[1]=~m/data abort/)
      {
        print "DATA ABORT!\n";
        my $a=<$sock>;
      }
    }
    else
    {
      print OUT "Memory access $dadr out of range, not trying to read it...\n";
    }
  }

    

  my $oldpc=$pc;
  my $oldisa=$isa;
  my $oldmode=$mode;

  print "stepping...\n";
  print $sock "step\n";
  $lines=getlines(5);
  if($mode eq "Abort")
  {
    $lines.=<$sock>;
    $lines.=<$sock>;
  }

  my $dbgline="$oldpc->$pc $oldisa $oldmode $disasm ";

  foreach my $r(@regs)
  {
    print $sock "reg $r\n";
    my @reglines=getlines(2);
    print "regline: $reglines[1]";
    my $oldv=$rval{"r$r"};
    my $newv=$1 if($reglines[1]=~m/(0x\w+)/);
    print "r$r old:$oldv new:$newv\n";
    $dbgline.=$oldv eq $newv?"r$r=$oldv ":"r$r:$oldv=>$newv ";
  }

  if(defined($dadr))
  {
    print $sock "$core mdw $dadr\n";
    my @dlines=getlines(2);
    if($dlines[1]=~m/(0x\w+): (\w+)/)
    {
      my $newv=$2;
      print "Data value at $adr was $dvalue now $newv\n";
      $dbgline.=$dvalue eq $newv?"[$dadr]=$dvalue ":"[$dadr]:$dvalue=>$newv ";
    }
   
  }
  $dbgline=~s/\x00//sg;
  print "DBGLINE: $dbgline\n";
  print OUT $dbgline."\n";

  print "DONE $lines[1]\n";
  if(defined($ARGV[1]) && $counter eq $ARGV[1])
  {
    if($ARGV[2]eq "resume")
    {
      print $sock "resume\n";
    }
    print OUT "Exiting after $counter instructions\n";
    print "Exiting after $counter instructions\n";
    exit;
  }

  $counter++;
  print "Counter: $counter\n";

}




while(0)
{
#  print $sock "step\n";
#  my $lines=getlines(5);

#  print $sock "resume\n";
#  print $sock "halt\n";
#  my $lines=getlines(6);
#  print OUT "resume halt\n";

  foreach(0 .. 220)
  {
    print $sock "step\n";
    my $lines=getlines(5);
  }


  if($adr<0xFFFFFFFF)
  {
    my $adrx=sprintf("%X",$adr);

    if(-s "ssdbad/mem0x$adrx")
    {
      print $sock "dump_image ssdgood2/mem0x$adrx 0x$adrx 0x10000\n";
      my $lines=getlines(2);
    }
    #my $sx=-s "ssdbad/mem0x$adrx";
    #$adr+=$sx?0x10000:0x10000;
    $adr+=0x10000;
  }

}


#print $sock "halt\n";
#my $linesh=getlines(1);

while($adr<0xFFFFFFFF)
{
  if (-f "end")
  {
    print OUT "Exiting due to end request\n";
    exit;
  }
  my $adrx=sprintf("%X",$adr&0xffff0000);

  if(-s "ssdbad/mem0x$adrx")
  {
    my $tadr=$adr+64;
    my $tadrx=sprintf("%X",$tadr);

    print "Reading 1\n";
    print $sock "$core mdw $tadr\n";
    my @lines=getlines(2);
    print "lines1: $lines[1]\n";
    if($lines[1]=~m/0x([0-9a-f]{8})\s+([0-9a-f]{8})/)
    {
      if(hex($1) ne $tadr)
      {
        print "OUT OF SYNC!\n";
        exit;
      }

      my $origv=$2;
      print "adr $tadrx value $origv\n";

      print $sock "$core mdw $tadr\n";
      my @lines=getlines(2);
      if($lines[1]=~m/0x([0-9a-f]{8})\s+([0-9a-f]{8})/)
      {
        if(hex($1) ne $tadr)
        {
          print "OUT OF SYNC!\n";
          exit;
        }

        my $next=$2;
        if($next eq $origv)
        {
          print "adr $tadrx value $origv MATCH\n";
          $next=hex("0x".$origv)^0x123;

          print $sock "$core mww $tadr $next\n";
          print $sock "$core mdw $tadr\n";
          print $sock "$core mww $tadr 0x$origv\n";
          print $sock "$core mdw $tadr\n";

          my @linesr=getlines(6);
          if($linesr[2]=~m/0x([0-9a-f]{8})\s+([0-9a-f]{8})/)
          {
            if(hex($1) ne $tadr)
            {
              print "OUT OF SYNC!\n";
              print OUT "OUT OF SYNC!\n";
              exit;
            }
            print "FOUND $2\n";
            if(hex($2) == $next)
            {
              print "Address $tadr is WRITEABLE\n";
            }
            else
            {
              print "Address $tadr is NOT WRITEABLE\n";
            }
          }
          elsif($linesr[1]=~m/data abort at/)
          {

          }

        }
        else
        {
          print "Values do not match: $tadrx $origv $next !\n";
          print OUT "Values do not match: $tadrx $origv $next !\n";
          exit;
        }

      }
      else
      {
        print "Could not find second value!\n";
        print OUT "Could not find second value!\n";
        exit;
      }

    }
    else
    {
      print "Could not find first value!\n";
      print OUT "Could not find first value!\n";
      exit;
    }


#    my $lines2=getlines(2);
  }
  #my $sx=-s "ssdbad/mem0x$adrx";
  #$adr+=$sx?0x10000:0x10000;
  print "addr: ".sprintf("0x%X\n",$adr);
  $adr+=0x1000;
}
