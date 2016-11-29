#!/usr/bin/perl -w

# http://www.t13.org/documents/uploadeddocuments/docs2008/d1699r6a-ata8-acs.pdf
# https://github.com/bahamas10/openzfs/blob/master/usr/src/uts/common/sys/scsi/adapters/pmcs/ata8-acs.h

my %SATACOMMAND=(
0x00=>"NOP",
0x03=>"CFA REQUEST EXTENDED ERROR",
0x06=>"DATA SET MANAGEMENT",
0x08=>"DEVICE RESET",
0x0b=>"REQUEST SENSE DATA EXT",
0x10=>"ADD LBA(S) TO NV CACHE PINNED SET",
0x20=>"READ SECTOR(S)",
0x21=>"READ SECTOR(S) WITHOUT RETRIES",
0x22=>"READ LONG",
0x23=>"READ LONG WITHOUT RETRIES",
0x24=>"READ SECTOR(S) EXT",
0x25=>"READ DMA EXT",
0x26=>"READ DMA QUEUED EXT",
0x27=>"READ NATIVE MAX ADDRESS EXT",
0x29=>"READ MULTIPLE EXT",
0x2A=>"READ STREAM DMA EXT",
0x2B=>"READ STREAM EXT",
0x2F=>"READ LOG EXT",
0x30=>"WRITE SECTOR(S)",
0x31=>"WRITE SECTOR(S)",
0x32=>"WRITE LONG",
0x33=>"WRITE LONG WITHOUT RETRIES",
0x34=>"WRITE SECTOR(S) EXT",
0x35=>"WRITE DMA EXT",
0x36=>"WRITE DMA QUEUED EXT",
0x37=>"SET MAX ADDRESS EXT",
0x38=>"CFA WRITE SECTOR(S) WITHOUT ERASE",
0x39=>"WRITE MULTIPLE EXT",
0x3A=>"WRITE STREAM DMA EXT",
0x3B=>"WRITE STREAM EXT",
0x3C=>"CFA WRITE VERIFY",
0x3D=>"WRITE DMA FUA EXT",
0x3E=>"WRITE DMA QUEUE FUA EXT",
0x3F=>"WRITE LOG EXT",
0x40=>"READ VERIFY SECTOR(S)",
0x41=>"READ VERIFY SECTOR(S) WITHOUT RETRIES",
0x42=>"READ VERIFY SECTOR(S) EXT",
0x45=>"WRITE UNCORRECTABLE EXT",
0x47=>"READ LOG DMA EXT",
0x50=>"CFA FORMAT SECTORS",
0x51=>"CONFIGURE STREAM",
0x57=>"WRITE LOG DMA EXT",
0x5B=>"TCG TRUSTED NONDAT SEND/RECEIVE",
0x5C=>"TCG TRUSTED RECEIVE",
0x5D=>"TCG TRUSTED RECEIVE DMA",
0x5E=>"TCG TRUSTED SEND",
0x5F=>"TCG TRUSTED SEND DMA",
0x60=>"READ FPDMA QUEUED",
0x61=>"WRITE FPDMA QUEUED",
0x63=>"NCQ ABORT",
0x64=>"NCQ DATA SET MANAGEMENT",
0x65=>"SEND/RECEIVE FPDMA QUEUED",
0x70=>"SEEK",
0x85=>"Disable the APM feature set",
0x87=>"CFA TRANSLATE SECTOR",
0x8F=>"Format Unit, Defect List Utility",
0x90=>"EXECUTE DEVICE DIAGNOSTIC",
0x91=>"INITIALIZE DEVICE PARAMETERS",
0x92=>"DOWNLOAD MICROCODE",
0x93=>"DOWNLOAD MICROCODE",
0x9A=>"Read Channel Buffer",
0xA1=>"IDENTIFY PACKET DEVICE",
0xA2=>"SERVICE",
0xB0=>"SMART VARIOUS COMMANDS",
0xB1=>"DEVICE CONFIGURATION",
0xB4=>"SANITIZE DEVICE",
0xB6=>"NV CACHE",
0xB9=>"CFA KEY MANAGEMENT",
0xC0=>"CFA ERASE SECTORS",
0xC4=>"READ MULTIPLE",
0xC5=>"WRITE MULTIPLE",
0xC6=>"SET MULTIPLE MODE",
0xC7=>"READ DMA QUEUED",
0xC8=>"READ DMA",
0xC9=>"READ DMA WITHOUT RETRIES",
0xCA=>"WRITE DMA",
0xCB=>"WRITE DMA WITHOUT RETRIES",
0xCC=>"WRITE DMA QUEUED",
0xCD=>"CFA WRITE MULITIPLE WITHOUT ERASE",
0xCE=>"WRITE MULTIPLE FUA EXT",
0xD1=>"CHECK MEDIA CARD TYPE",
0xDA=>"GET MEDIA STATUS",
0xDE=>"MEDIA LOCK",
0xDF=>"MEDIA UNLOCK",
0xE0=>"STANDBY IMMEDIATE",
0xE1=>"IDLE IMMEDIATE",
0xE2=>"STANDBY",
0xE3=>"IDLE",
0xE4=>"READ BUFFER",
0xE5=>"CHECK POWER MODE",
0xE6=>"SLEEP",
0xE7=>"FLUSH CACHE",
0xE8=>"WRITE BUFFER",
0xE9=>"READ BUFFER DMA",
0xEA=>"FLUSH CACHE EXT",
0xEB=>"WRITE BUFFER DMA",
0xEC=>"IDENTIFY DEVICE",
0xED=>"MEDIA EJECT",
0xEF=>"SET FEATURES",
0xF1=>"SECURITY SET PASSWORD",
0xF2=>"SECURITY UNLOCK",
0xF3=>"SECURITY ERASE PREPARE",
0xF4=>"SECURITY ERASE UNIT",
0xF5=>"CFA WEAR LEVEL/SECURITY FREEZE LOCK",
0xF6=>"SECURITY DISABLE PASSWORD",
0xF7=>"READ NATIVE MAX ADDRESS",
0xF8=>"READ NATIVE MAX ADDRESS",
0xF9=>"SET MAX ADDRESS");

open IN,"<:raw","mem0x810000";
undef $/;
my %mem=();
$mem{0x810000}=<IN>;
close IN;

sub try
{
  my $m8=$_[0]+8;
  my $m4=$_[0]+4;
  my $mc=$_[0]+0xc;
  my $cmd=$_[1];
  my $d8=unpack("V",substr($mem{$m8&0xffff0000},$m8&0xffff,4));
  my $state=($d8 eq $cmd) ? "FOUND":"NOT FOUND";

#  print "".sprintf("%08X",$d8)." $state ";

  if($state eq "FOUND")
  {
    #print "<td>$state</td>";
    my $d4=unpack("V",substr($mem{$m4&0xffff0000},$m4&0xffff,4));
    my $dc=unpack("V",substr($mem{$mc&0xffff0000},$mc&0xffff,4));
    print "<td>$state</td><td>".sprintf("0x%08X",$d4)."</td>";
    print "<td>".($d4&1)."</td><td>".sprintf("0x%08X",$dc)."</td>";
    print "<td><a href='http://www2.futureware.at/cgi-bin/ssd/showmem?addr=".sprintf("0x%08X",$dc)."' target='_blank'>Mem</a></td>";
    print "<td><a href='http://www2.futureware.at/cgi-bin/ssd/comment?addr=".sprintf("0x%08X",$dc)."' target='_blank'>Comment</a></td>";
    print "<td><a href='http://www2.futureware.at/cgi-bin/ssd/searchlog?q=".sprintf("0x%08X",$dc)."->' target='_blank'>Log</a></td>";
  }

  if($d8 ne $cmd)
  {
    my $m=unpack("V",substr($mem{$_[0]&0xffff0000},$_[0]&0xffff,4));
    try($m,$_[1]) if($m);
  }
}

print "<html><body><table border='1'><tr><td>Cmd</td><td>CMD</td><td>Command</td><td>Handler</td><td>Bitfield</td><td>Bit 0</td><td>Address</td><td>Showmem</td><td>Comment</td><td>SearchCode</td></tr>\n";
foreach my $cmd(0 .. 255)
{
  print "<tr><td>$cmd</td><td>".sprintf("%02Xh",$cmd)."</td><td>".($SATACOMMAND{$cmd}||"SECRET COMMAND")."</td>";
  my $mul=($cmd * 2654435769)&0xffffffff;
  my $shr=$mul>>28;
  my $shr3=$shr*3;
  my $pos=(((($cmd * 2654435769)&0xffffffff) >> 28)*3)<<2;
  my $mempos=0x0081F59C+$pos;
  my $mv=unpack("V",substr($mem{$mempos&0xffff0000},$mempos&0xffff,4));
  #print "".sprintf("%08X",$mul)." ".sprintf("%08X",$shr)." ".sprintf("%08X",$shr3)." ".sprintf("%08X",$pos)." ".sprintf("%08X",$mempos)." ".sprintf("%08X",$mv)." ";
  try($mv,$cmd);
  print "</tr>\n";
}
print "</table></body></html>\n";

