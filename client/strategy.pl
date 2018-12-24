#!/usr/bin/perl -w
use strict;
use IO::Socket::INET;
use Getopt::Long;
use POSIX qw(strftime);

our $power="";
our $debug=0;
our $skipregs=0;
our $coretodo="mex1";
our $safe=0; # $safe=1 if($coretodo=~s/safe//);
our $resumeAtEnd=0;
our $workload=undef;
our $sector="random";
our $moresteps=0;
our $state=0;
our $nsteps=-1;
our $modifier=0x0;
our $modifiermax=0x0; # was 0x300
our $restartopenocd=1;  # Restart or reuse OpenOCD
our $ignoreloops=1;
our $allcores=0;
our $breakpoint=undef;
our $action="";


GetOptions ("debug" => \$debug,
            "skipregs" => \$skipregs,
            "core=s" => \$coretodo,
            "safe" => \$safe,
            "resume" => \$resumeAtEnd,
            "workload=s" => \$workload,
            "sector=s" => \$sector,
            "moresteps=i" => \$moresteps,
            "nsteps=i" => \$nsteps,
            "power=s" => \$power,
            "restartopenocd=i" => \$restartopenocd,
            "ignoreloops" => \$ignoreloops,
            "modifiermax=i" => \$modifiermax,
            "breakpoint=s" => \$breakpoint,
            "action=s" =>\$action);

unlink "done";

our $core=$coretodo;

if($coretodo eq "all")
{
  $allcores=1;
  $core="mex1";
}

if($power)
{
  system "killall -9 dd openocd 2>/dev/null";
  print "Power Off\n";
  system "perl poweroff.pl";
  system "bash rescan.sh";
  print "Power On\n";
  system "perl poweron$power.pl";
  sleep(10);
  unlink "workloadinfo";
  my $COUNT=int(rand(1000));
  system "dd if=/dev/sda of=/dev/null count=$COUNT";
}
unlink "done";


if($restartopenocd)
{
  print "Restarting OpenOCD ...\n";
  system "killall openocd ".($debug?"":"2>/dev/null");
  sleep(1);
  system "/usr/local/bin/openocd -f ".($safe?"mex1":"openocd").".conf ".($debug?"":"2>/dev/null")."&";
  sleep(5);
}

$sector=int(rand(1000000)) if($sector=~m/rand/);
print "Using sector $sector\n";

#my $sock=IO::Socket::INET->new(PeerAddr=>"localhost:4444");
my $openocd=IO::Socket::INET->new(PeerAddr=>"localhost:6666");

sub readfile($)
{
  my $RIN;
  if(open($RIN,"<:raw",$_[0]))
  {
    my $oldp=$/;
    undef $/;
    my $data=<$RIN>;
    close $RIN;
    $/=$oldp;
    return $data;
  }
  return undef;
}

sub ocd($)
{
  print STDERR "-> $_[0]\n" if($debug);
  $openocd->send("$_[0]\x1a");
  my $old=$/;
  $/="\x1a";
  my $v="";
  my $ende=0;
  while(!$ende)
  {
    my $a="";
    $openocd->recv($a,1);
    #print "a: $a\n";
    if($a eq "\x1a")
    {
      $ende=1;
      #print STDERR "END\n";
    }
    else
    {
      $v.=$a;
      #print $a;
    }
  }
  print STDERR "<- $v\n" if($debug);
  $/=$old;
  return $v;
}


sub getMem($)
{
  return "unknown" if($_[0]=~m/unknown/);
  my $v=ocd("ocd_mdw $_[0]");
  print STDERR "mdw: $v\n" if($debug);
  my $val=substr($v,12,8);
  if($val!~m/^[0-9a-f]{8}$/)
  {
    print "Error: $v\n";
    if($v=~m/Target not examined yet/)
    {
      print "SSD does not seem to be powered up or properly connected, or the debug interface crashed. Please check the connection and OpenOCD settings in mex1.conf, and restart the SSD if necessary\n";
      exit;
    }
    return "unknown";
  }
  #print STDERR "val: $val\n";
  return $val;
}

sub getMemDump($$)
{
  my $v=ocd("ocd_mdb $_[0] $_[1]");
  return $v;
}



open OUT,">>debug$core".($workload||"").$sector.".log";
sub printo($)
{
  print $_[0];
  print OUT $_[0];
}

printo "\nstarting $core ".strftime("%Y-%m-%d %H:%M:%S",localtime())."\n";
sub showWorkload_($)
{
  my $sector=$_[0];
  printo "LBA512B-Sector: $sector ".sprintf("0x %X",$sector)."\n";
  printo "LBA4K: ".sprintf("0x %X",$sector>>3)."\n";
  printo "LBA4Kbit1: ".sprintf("0x %X",($sector>>3)&1)." -> mex".((($sector>>3)&1)+2)."\n";
  printo "LBA8K: ".sprintf("0x %X",$sector>>4)."\n";
  printo "LBA4Kdiv511: ".sprintf("0x %X",($sector>>3)/511)."\n";
  printo "LBA4Kmod511: ".sprintf("0x %X",($sector>>3)%511)."\n";
  printo "LBA8Kbit1: ".sprintf("0x %X",($sector>>4) & 1)."\n";
  printo "LBA8Kbit3: ".sprintf("0x %X",($sector>>4) & 3)."\n";
  printo "LBA32K: ".sprintf("0x %X",$sector>>6)."\n";
  printo "LBA32Kmod128: ".sprintf("0x %X",($sector>>6)&127)."\n";
  printo "LBA32div3760: ".sprintf("0x %X",($sector>>6)/3760)."\n";
  printo "LBA32mod3760: ".sprintf("0x %X",($sector>>6)%3760)."\n";
  printo "LBA32mod3760t25div32: ".sprintf("0x %X",(($sector>>6)%3760)*25/32)."\n";
  printo "LBA32mod3760t25mod32: ".sprintf("0x %X",(($sector>>6)%3760)*25%32)."\n";
  printo "Base81BDFC 4Kmod511: ".sprintf("0x %X",((($sector>>3)%511)*4)+8502780)."\n";
  printo "Base80106C (0x801520) 8Kmod4: ".sprintf("0x %X", 0x00801520 + 76*(($sector>>4) & 3))."\n";
}

sub showWorkload($)
{
  my $sector=$_[0];
  printo "LBA512B-Sector: $sector ".sprintf("0x %X",$sector)."\n";
  printo "LBA4K: ".sprintf("0x %X",$sector>>3)."\n";
  my $sectormex="mex".((($sector>>3) & 1 )+ 2);
  printo "LBA4Kbit1: ".sprintf("0x %X",($sector>>3) & 1)." -> $sectormex\n";
  printo "LBA4Kdiv511: ".sprintf("0x %X",($sector>>3)/511)."\n";
  printo "LBA4Kmod511: ".sprintf("0x %X",($sector>>3)%511)."\n";
  printo "LBA8K: ".sprintf("0x %X",$sector>>4)."\n";
  printo "LBA8Kbit1: ".sprintf("0x %X",($sector>>4) & 1)."\n";
  printo "LBA8Kbit3: ".sprintf("0x %X",($sector>>4) & 3)."\n";
  printo "LBA32K: ".sprintf("0x %X",$sector>>6)."\n";
  printo "LBA32Kmod128: ".sprintf("0x %X",($sector>>6)&127)."\n";
  printo "LBA32div3760: ".sprintf("0x %X",($sector>>6)/3760)."\n";
  printo "LBA32mod3760: ".sprintf("0x %X",($sector>>6)%3760)."\n";
  my $LBA32mod3760t25div32=int((($sector>>6)%3760)*25/32);
  my $LBA32mod3760t25mod32=(($sector>>6)%3760)*25%32;
  print "LBA32mod3760t25div32: $LBA32mod3760t25div32\n";
  print "LBA32mod3760t25mod32: $LBA32mod3760t25mod32\n";
 
  my @bases1C860=(0x0001C860, 0x0001C868, 0x0001C870, 0x0001C878,0x0001C840, 0x0001C848, 0x0001C850, 0x0001C858);
  my @highbases=(0x82c93000,0x84c1f000,0x86bab000,0x88b3a000,0x91693000,0x9361F000,0x955AB000,0x9753A000);

  #foreach my $base1C860 (0x0001C860, 0x0001C868, 0x0001C870, 0x0001C878)
  my $base1C860=$bases1C860[($sector>>4) & 3];
  #{
    print "1C860: ".(($base1C860>>3)&3)."\n";
    print "LBA8K3: ".(($sector>>4) & 3)."\n";

    #my $val=getMem($base1C860);
    my $val=sprintf("0x%X",$highbases[(($sector>>4) & 3)+((($sector>>3) & 1)<<2)]);
    #$val=0x82c93000+(0x1F8C0000*(($sector>>4) & 3)); This does not work, since the 4 ranges are not in a mathematical order

    print "base1C860: [".sprintf("0x%X",$base1C860)."]=$val\n";

    print "Expected FTL table: ".sprintf("0x%X",$highbases[($sector>>4) & 3])."\n";

    if(hex($val) != $highbases[(($sector>>4) & 3)+((($sector>>3) & 1)<<2)])
    {
      print "The base address $val is out of range: $val vs. ".sprintf("0x%X",$highbases[($sector>>4) & 3])." !\n";
      print "Perhaps the FTL table in RAM is not loaded?\n";
      print "It should be either 82c93000 84c1f000 86bab000 88b3a000 instead!\n";
      return;
    }

    my $ramaddr=hex($val)+0x3000*int(($sector>>6)/3760);
    print "ramaddr: ".sprintf("0x%X",$ramaddr)."\n";
    my $myram=$ramaddr+4*((25*(($sector>>6)%3760)>>5));
    print "myram: $myram (".sprintf("0x%X",$myram).")\n";

  return;
  ocd("targets $sectormex");
  ocd("halt");


    my $myvalL=getMem($myram);
    my $myvalH=getMem($myram+4);
    print "myramL: [".sprintf("0x%X",$myram)."]=$myvalL\n";
    print "myramH: [".sprintf("0x%X",$myram+4)."]=$myvalH\n";

    my $FTLaddr=((hex($myvalL) >> $LBA32mod3760t25mod32) | 2 * (hex($myvalH) << (31 - $LBA32mod3760t25mod32))) & 0x1FFFFFF;
    print "FTLaddr: $FTLaddr ".sprintf("0x%X",$FTLaddr)."\n";
    my $v8010F0=0x200;
    my $v8010E0=0x20BC; # 8380
    my $FTL9=$FTLaddr>>9;
    print "FTL9: $FTL9 ".sprintf("0x%X",$FTL9)."\n";
    my $LPA = $FTL9 + 180 * int(int($FTL9 / ($v8010E0 - 180)) + 1);
    print "LPA: $LPA (".sprintf("0x%X",$LPA).")\n";
    my $zone=int($LPA/$v8010E0);
    print "Zone: $zone\n";
    my $PBN=$LPA % $v8010E0;
    print "PBN: $PBN ".sprintf("0x%X",$PBN)."\n";
    my $PBPN=($PBN<<8) | (($FTLaddr>>1)&0xff);
    print "PBPN: $PBN ".sprintf("0x%X",$PBPN)."\n";
    #$expectedPBPN=$PBPN;
  #}
  printo "LBA32mod3760t25div32: ".sprintf("0x %X",(($sector>>6)%3760)*25/32)."\n";
  printo "LBA32mod3760t25mod32: ".sprintf("0x %X",(($sector>>6)%3760)*25%32)."\n";
  printo "Base81BDFC 4Kmod511: ".sprintf("0x %X",((($sector>>3)%511)*4)+8502780)."\n";
  printo "Base80106C (0x801520) 8Kmod4: ".sprintf("0x %X", 0x00801520 + 76*(($sector>>4) & 3))."\n";

  ocd("targets $core");
  #ocd("resume");
}






if($action eq "delaytest")
{
  foreach my $n(1 ..10)
  {
    my $delay=$n*120;
    print "Trying a delay of $delay seconds:\n";
    ocd("targets $core");
    ocd("halt");
    system "bash workload_$workload.sh $sector &" ;
    sleep($delay);
    ocd("resume");
    sleep(3);
    open IN,"<result";
    my $err=0;
    my $good=1;
    while(<IN>)
    {
      $err=1 if(m/response length too short/);
      $good=1 if(m/Command=SMART READ LOG/);
    }
    close IN;
    if($err)
    {
      print "$delay seconds is too long!\n";
      exit;
    }
    if(!$good)
    {
      print "Result is not good. Exiting\n";
      exit;
    }
    #exit;
  }
  print "We succeeded.\n";
  exit;



}


showWorkload($sector);

ocd("$core arp_examine") if($core=~m/^mex\d+/);
ocd("mex1 arp_examine");
ocd("mex2 arp_examine") if(!$safe);
ocd("mex3 arp_examine") if(!$safe);




my @stacks=(
["SVC",0x803a0200,0x803a1200,"25"],
["SVC",0x826C00,0x827C00,"25"],
["FIQ",0x827C00,0x827C80,"21"],
["IRQ",0x827C80,0x827D80,"23"],
["UND",0x827D80,0x827E00,"29"],
["ABT",0x827E00,0x827F00,"27"],
#["USR",0x0E21E99B,0x0E21E99B,"13"] # Yes, this is the tragedy, the UserSpace Stack
);

ocd("targets mex1");
printo "Service Stack: ".getMem(0x80030354)."\n";

foreach my $core("mex1","mex2","mex3")
{
  printo "Stacks of core $core:\n";
  next if($power eq "safe" && $core ne "mex1");
  ocd("targets $core");
  foreach my $s(@stacks)
  {
    #printo "reg: $s->[3]\n";
    my $sp="unknown"; $sp=$1 if(ocd("ocd_reg ".($s->[3]))=~m/0x(\w+)/);
    printo "Stack Pointer $s->[0]: 0x$sp\n";
    if($sp ne "unknown" && hex($sp)>=$s->[1] && hex($sp)<=$s->[2])
    {
      my $i;
      foreach($i=hex($sp); $i<=$s->[2];$i+=4)
      {
        my $pos=getMem($i);
        my $h=hex($pos);
        my $d=""; $d="*" if(($h>=0x64 && $h<=0x20000) || ($h>=0x80000200 && $h<=0x800B0000));
        printo "Stack Value: [".sprintf("0x%X",$i)."] : 0x".getMem($i)." $d\n";
      }
    }
  }
}

printo "Halting mex1\n";
ocd("targets mex1");
ocd("halt");

if($allcores)
{
  ocd("targets mex1");
  ocd("halt");
  ocd("targets mex2");
  ocd("halt");
  ocd("targets mex3");
  ocd("halt");
}

my $ofh=select OUT;
$|=1;
select STDOUT;

our %skippoints=();
our %jumppoints=();
our %breakpoints=();
our %startpoints=();
our %injects=();

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

sub LoadJumps()
{
 %skippoints=();
 %jumppoints=();
 %breakpoints=();
 %startpoints=();
 %injects=();
 foreach my $f(<goodlogs/$core*>)
 {
  open LIN,"<$f";
  $/="\n";
  printo "Reading $f\n";
  while(<LIN>)
  {
    #printo $_;
    if(m/^(0x\w+).*SKIP\((0x\w+)\)/)
    {
      $skippoints{lc $1}=$2;
      printo "$f: We will set a Skippoint on $1 to skip to $2\n";
    }
    if(m/^(0x\w+).*JUMP\((0x\w+)\)/)
    {
      $jumppoints{lc $1}=$2;
      printo "$f: We will set a Jumppoint on $1 to skip to $2\n";
    }
    if(m/^(0x\w+).*BREAKPOINT/)
    {
      $breakpoints{lc $1}=1;
      printo "$f: We will set a Breakpoint on $1 immediately\n";
      ocd("bp $1 4 hw");
    }
    if(m/^(0x\w+).*STARTPOINT/)
    {
      my $addr=$1;
      $startpoints{lc $addr}=1;
      printo "$f: We will start at $addr immediately\n";
      ocd("targets $core");
      ocd("bp $addr 4 hw");
    }
    if(m/^(0x\w+).*INJECT\(([^\)]*)\)/)
    {
      my $addr=$1;
      my $do=$2;
      $injects{lc $addr}.=$do."\n";
      printo "$f: We will inject code at $addr : $do\n";
      ocd("targets $core");
      ocd("bp $addr 4 hw");
    }

  }
  close LIN;
 }
}

LoadJumps();

our $isa="";
our $mode="";
our $pc="";
our $cpsr="";
our %nvisited=();

sub analyzepos($)
{
  my $a=$_[0];
  if($a=~m/cpsr: (0x\w{8}) pc: (0x\w{8})/)
  {
    #print "CPRS: $1,PC: $2\n";
    $cpsr=$1;
    $pc=$2;
  }
  if($a=~m/target halted in (\w+) state.*current mode: (\w+)/)
  {
    if($isa ne $1 || $mode ne $2)
    {
      $isa=$1;
      $mode=$2;
      #print "ISA,MODE: $isa,$mode\n";
    }
  }
  if(defined($injects{$pc}))
  {
    print "Found Injection point!\n";
    foreach my $code(split "\n",$injects{$pc})
    {
      next unless($code);
      $code=~s/\$MODIFIER/$modifier/g;
      printo "Executing Injection $code\n";
      my $res=ocd($code);
      printo "Result: $res\n";
    }
    printo "Injection done. Continuing...\n";
    ocd("rbp $pc");
    ocd("rbp 0x000014c8");
    ocd("step");
    ocd("step");
    ocd("step");
    #ocd("bp 0x000014c8 4 hw");
    $state=-1;
    ocd("resume"); # if($state<0);
    sleep(1);
  }

  if(-l "workloadinfo")
  {
    print "DETECTED WORKLOAD INFO\n";
    my $wlinfo=readlink("workloadinfo");
    printo "\nWorkload Info: $wlinfo\n";
    if($wlinfo=~m/sector_(\d+)/)
    {
      showWorkload($1);
    }
    unlink "workloadinfo";
  }
  if(-f "done")
  {
    printo "Done: Workload finished.\n";
    printo "Result:\n".readfile("result")."\n" if(-s "result");
    if($modifier<$modifiermax)
    {
      system "mv sample sample".sprintf("%X",$modifier);
      unlink "done";
      $modifier++;   
      printo "Next Modifier: $modifier\n";
      print "Registering breakpoint again:\n";
      ocd("bp 0x000014c8 4 hw");

      if(defined($workload))
      {
        sleep(3);
        printo "Starting workload $workload\n";
        system "bash workload_$workload.sh $sector &" ;
        sleep(1);
      }
      
    }
    else
    {
      $state=1;
      printo "".($moresteps?"We do some final steps now ...\n":"We are done.\n");
      exit unless($moresteps);
    }
  }

  if((($core eq "mex2") && (hex($pc) == 0x018682)) || (($core eq "mex3") && (hex($pc) == 0x1865e)))
  {
    printo "We got a command on $core (pc:$pc)\n";

    my $base=($core eq "mex2")?0x41800000:0x42800000;
    my $counter=getMem($base+0x874);
    printo "Requests that were delegated to core:\n";
    printo "Current ringbuffer element: ".hex($counter)."0x$counter\n"; 
    foreach my $mod(0 .. 61)
    {
      my $mybase=$base+0x90+32*$mod;
      printo "".sprintf("%02d",$mod).((hex($counter)==$mod)?"**":": ")."LBA8K: ".getMem($mybase+8)." M:".getMem($mybase+20)." ".getMemDump($mybase,32);
    }
  }
 
}

my $adr=0xFFFF0000;


  ocd("targets $core");
  analyzepos(ocd("ocd_halt"));

  print "Now we look whether the core is running and we halt it if it is still running\n";
  if(ocd("ocd_targets")=~m/$core\s+cortex_r4\s+little\s+\S+\s+(halted|running)/)
  {
    print "$core is $1\n";
    if($1 eq "running")
    {
      ocd("halt");
    }
  }

  # Disabling core3 to prevent race conditions
  if(0)
  {
    printo "Disabling MEX3 to prevent race conditions\n";
    ocd("targets mex3");
    ocd("halt");
    ocd("targets $core");
  }


printo "Status: ".ocd("ocd_targets")."\n";

unlink "done";
if(defined($workload))
{
  printo "Starting workload $workload\n";
  system "bash workload_$workload.sh $sector &" ;
  sleep(2);

}

if($workload eq "safe2normal")
{
  print "Now we are restarting the SAFE bootloader:\n";
  ocd("mwh 0xa314 0x46c0");
  ocd("reg pc 0x0");
  ocd("reg cpsr 0xd3");
  if(defined($breakpoint))
  {
    print "Setting breakpoint:\n";
    ocd("bp $breakpoint 4 hw");
    print "Starting:\n";
    ocd("resume");
    sleep(2);
    print "Poll: ".ocd("ocd_poll")."\n";

    if(0) # Restart OpenOCD and look whether MEX2 has come up
    {
      system "killall openocd ".($debug?"":"2>/dev/null");
      sleep(1);
      system "/usr/local/bin/openocd -f openocd.conf >.log.openocd1 2>.log.openocd2 &";
      sleep(5);
      system "killall openocd ".($debug?"":"2>/dev/null");
      open IN,"<.log.openocd2";
      while(<IN>)
      {
        if(m/mex2/)
        {
          symlink 1,"bootlogging/$breakpoint";
          exit(1);
        }
      }
      close IN;
      symlink 0,"bootlogging/$breakpoint";
      exit(0);
    }
    else # Read a value from RAM
    {
      print "Exiting so that we can read directly\n";
      ocd("targets 0");
      ocd("halt");
      exit(); # hex(getMem("0x823050")));

    }
  }
}


if(%startpoints)
{
  printo "Starting point defined. Trying to get there:\n";
  printo "$_\n" foreach(sort keys %startpoints);
  printo "Resuming:\n";
  ocd("resume");
  my $seconds=10;
  print "Waiting $seconds seconds:\n";
  sleep($seconds);
  printo "Halting:\n";
  ocd("halt");
  my $pc=ocd("ocd_reg pc");
  print "PC: --$pc--\n";
  $state=-1;
  analyzepos(ocd("ocd_poll"));
  foreach(keys %startpoints)
  {
    print "Removing breakpoint $_\n";
    ocd("rbp $_");
  }
  $state=0;
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


print OUT ocd("ocd_reg");
foreach(0 .. 41)
{
  print OUT ocd("ocd_reg $_");
}

#print "Please connect now:\n";
#system "bash";

my $counter=0;
while(1)
{
  if($allcores)
  {
    $core="mex".((substr($core,3)%3)+1);
    ocd("targets $core");
  }


  analyzepos(ocd("ocd_poll"));

  #printo("STATE: $state\n");

  while($state<0 && $modifier<$modifiermax)
  {
    printo("MODIFIER LOOP\n");
    analyzepos(ocd("ocd_poll"));
  }


  if(!($counter%100))
  {
    printo "Regular Diagnostics:\n";
    ocd("targets mex1");
    foreach("0x20501004","0x20501000","0x20501008")
    {
      printo($_.": ".getMem(hex($_))."\n");
    }
    if(getMem(0x823050)=~m/631fe/)
    {
      print "Found data loaded. Done.\n";
      exit;
    }
    LoadJumps();
  }


  my $oldcpsr=$cpsr;

  $nvisited{$pc}++;

  my @lines=split "\n",ocd("ocd_arm disassemble $pc 1 ".($isa eq "Thumb"?"thumb":""));
  my $disasm=$lines[0];
  $disasm=~s/[\r\n\0]//sg;


  my $dadr=undef;
  my $dvalue="";
  my $regs=$lines[0];
  my @regs=();
  my %rval=();
  # Parsing relevant registers
  print "DISASM: $disasm\n";


  if(!$skipregs)
  {

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
    my @reglines=split "\n",ocd("ocd_reg $r");
    #print "regline: $reglines[0]\n";
    $rval{"r$r"}=$1 if($reglines[0]=~m/(0x\w+)/);
  }
  while($regs=~s/(sp)//)
  {
    my $r=$1;
    next if(defined($regseen{$r}));
    $regseen{$r}=1;
    push @regs,$r;
    my @reglines=split "\n",ocd("ocd_reg $r");
    print "regline: $reglines[0]\n";
    $rval{"$r"}=$1 if($reglines[0]=~m/(0x\w+)/);
  }
  $rval{'pc'}=$pc;

  if($lines[0]=~m/\[(r\d+|pc)(, #(\w+))?\]/)
  {
    my ($base,$offset,$offvalue)=($1,$2,$3);
    print "Memory access detected: $base $offset $offvalue\n";
    $dadr=$rval{$base};
    if(defined($offset))
    {
      #print "dadr: $dadr , offset is defined\n";
      $dadr=sprintf("0x%08X",hex($dadr)+((substr($offvalue,0,2) eq "0x")?hex($offvalue):$offvalue));
      #print "dadr: $dadr\n";
      if($base eq "pc") #($base eq "r15") ||
      {
        $dadr =sprintf("0x%08X",hex($dadr)+(($isa eq "Thumb") ? 2:4));
        #print "dadr: $dadr (after pc)\n";
      }
    }
    if(checkmemrange(hex($dadr)))
    {
      $dvalue=getMem(hex($dadr));
      #print "Got dvalue: $dvalue\n";
    }
    else
    {
      print OUT "Memory access $dadr out of range, not trying to read it...\n";
      print "Memory access $dadr out of range, not trying to read it...\n";
    }
  }

  }

  my $oldpc=$pc;
  my $oldisa=$isa;
  my $oldmode=$mode;

  print "stepping...\n";
  analyzepos(ocd("ocd_step")); # A small step for ARM, a big step for us

  my $dbgline="$oldpc->$pc $oldisa $oldmode $disasm ";

  foreach my $r(@regs)
  {
    my @reglines=split "\n",ocd("ocd_reg $r");
    print "regline: $reglines[0]\n";
    my $oldv=$rval{"r$r"};
    my $newv=$1 if($reglines[0]=~m/(0x\w+)/);
    print "r$r old:$oldv new:$newv\n";
    $dbgline.=($oldv eq $newv)?"r$r=$oldv ":"r$r:$oldv=>$newv ";
  }

  if(defined($dadr))
  {
    my $newv=getMem(hex($dadr));
    #print "Data value at $adr was $dvalue now $newv\n";
    $dbgline.=($dvalue eq $newv)?"[$dadr]=$dvalue ":"[$dadr]:$dvalue=>$newv ";
  }

  if($oldcpsr ne $cpsr)
  {
    $dbgline.=" cpsr:$oldcpsr=>$cpsr ";
  }

  $dbgline=~s/\x00//sg;
  print "DBGLINE: $dbgline\n";
  print OUT $dbgline."\n";

  print "DONE $lines[0]\n";
  $moresteps-- if($state && $moresteps);
  if(($counter eq $nsteps) || ($state==1 && !$moresteps))
  {
    if($resumeAtEnd)
    {
      printo "Resuming at the end...\n";
      ocd("resume");
    }
    print OUT "Exiting after $counter instructions\n";
    print "Exiting after $counter instructions\n";
    exit;
  }

  print "Hit? $oldpc\n";
  if(defined($skippoints{$oldpc}))
  {
    print "Hitting skip point $oldpc, jumping to $skippoints{$oldpc}!\n";
    print OUT "Hitting skip point $oldpc, jumping to $skippoints{$oldpc}!\n";
    ocd("reg pc $skippoints{$oldpc}");
    next;
  }

  if(defined($jumppoints{$oldpc}))
  {
    printo "Hitting jump point $oldpc, jumping to $jumppoints{$oldpc}!\n";
    printo "bp $jumppoints{$oldpc} ".($jumppoints{$oldpc}&2?2:4)." hw\n";
    ocd("bp $jumppoints{$oldpc} ".($jumppoints{$oldpc}&2?2:4)." hw");
    printo "resuming ...\n";
    ocd("resume");
    printo ocd("ocd_halt");
    ocd("rbp $jumppoints{$oldpc}");
    next;
  }


  # Detecting short loops:
  if(!$ignoreloops && $disasm=~m/0x\w+\s+0x\w+\s+B\w+\s+(0x\w+)/ && $nvisited{$oldpc}>100)
  {
    if(hex($1)<hex($oldpc))
    {
      my $skip=sprintf("0x%08X",hex($oldpc)+($isa eq "Thumb"?2:4));
      my $skip2=sprintf("0x%08X",hex($oldpc)+($isa eq "Thumb"?4:4));
      printo"Loop detected! Trying to escape from $oldpc to $skip: if it does not work, add : $oldpc JUMP($skip2)\n";
      printo "$oldpc SKIP($skip)\n";
      ocd("bp $skip ".($isa eq "Thumb"?4:4)." hw"); # In case of long Thumb instructions we have to cover more
      ocd("resume");
      ocd("halt");
      ocd("rbp $skip");
      next;
    }
    else
    {
      print "This jump is backwards?!?\n";
      print OUT "This jump is backwards?!?\n";
    }
  }

  $counter++;
  print "Counter: $counter\n";
  #print "Additional sleep:\n";
  #sleep(1);

}




while(0)
{
#  print $sock "resume\n";
#  print $sock "halt\n";
#  my $lines=getlines(6);
#  print OUT "resume halt\n";

  foreach(0 .. 220)
  {
    #print $sock "step\n";
    #my $lines=getlines(5);
    analyzepos(ocd("ocd_step"));
  }


  if($adr<0xFFFFFFFF)
  {
    my $adrx=sprintf("%X",$adr);

    if(-s "ssdbad/mem0x$adrx")
    {
      #print $sock "dump_image ssdgood2/mem0x$adrx 0x$adrx 0x10000\n";
      #my $lines=getlines(2);
      ocd("dump_image ssdgood2/mem0x$adrx 0x$adrx 0x10000");
    }
    #my $sx=-s "ssdbad/mem0x$adrx";
    #$adr+=$sx?0x10000:0x10000;
    $adr+=0x10000;
  }

}


#print $sock "halt\n";
#my $linesh=getlines(1);

while($adr<0xF0000000)
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
    my $origv=getMem($tadr);
    if(1)
    {
      print "adr $tadrx value $origv\n";
      
      my $next=getMem($tadr);
        if($next eq $origv)
        {
          print "adr $tadrx value $origv MATCH\n";
          $next=hex("0x".$origv)^0x123;

          #print $sock "$core mww $tadr $next\n";
          #print $sock "$core mdw $tadr\n";
          #print $sock "$core mww $tadr 0x$origv\n";
          #print $sock "$core mdw $tadr\n";

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

    }


#    my $lines2=getlines(2);
  }
  #my $sx=-s "ssdbad/mem0x$adrx";
  #$adr+=$sx?0x10000:0x10000;
  print "addr: ".sprintf("0x%X\n",$adr);
  $adr+=0x1000;
}
