#!/usr/bin/perl -w

# This tool parses the segments of Samsung SSD firmware files (*.dec) and compares the extracted firmware segments against memory dumps found in the wild
# Additionally it generates radare2 scripts with information about the firmware to make parsing with radare easy

my @list=("good","good2","bad");
#my @list=("good","bad");

my $bgcolor="240 240 240 ";
my $existcolor="130 130 130 ";
my $markedcolor="255 0 0 ";

my $imgmgk='C:\\Program Files\\ImageMagick-6.8.9-Q16\\';
my $imagemagick=-d $imgmgk?$imgmgk:"";

our %r=();
our %w=();
our %x=();

our %comment=();
open IN,"<../../SSDcallback.txt";
while(<IN>)
{
  if(m/Section: start=(\w+) size=\w+\s*blocks=\w+\s+\d+ \wB (.*)/)
  {
    #print "Comm$1ent\n";
    $comment{$1}=$2;
  }
}
close IN;

my @ranges=();

sub mymin($$)
{
  return $_[0]>$_[1]?$_[1]:$_[0];
}

sub loadMemory($$$) # Loads a contiguous memory area from a dump directory ($directory,$start,$size)
{
  my $pos=$_[1]&0xFFFF0000;
  my $mem="";
  while($pos<($_[1]+$_[2]+0x20000))
  {
    if(open INM,"<:raw","$_[0]/mem0x".sprintf("%X",$pos))
    {
      undef $/;
      $mem.=<INM>;
      close INM;
    }
    $pos+=0x10000;
  }
  return substr($mem,($_[1]&0xFFFF),mymin($_[2],length($mem)-($_[1]&0xFFFF)));
}

sub sayBytes($)
{
  return int($_[0]/1024/1024/1024/1024)." TB" if($_[0]>=1024*1024*1024*1024);
  return int($_[0]/1024/1024/1024)." GB" if($_[0]>=1024*1024*1024);
  return int($_[0]/1024/1024)." MB" if($_[0]>=1024*1024);
  return int($_[0]/1024)." KB" if($_[0]>=1024);
  return int($_[0])." B";
}


foreach my $fn(<*.dec>)
{
  print "fn:$fn\n";
  my $content="";
  if(open INR,"<:raw","$fn")
  {
    undef $/;
    $content=<INR>;
    close INR;
  }

  print "Length: ".length($content)."\n";

  open OUT,">$fn.r2";
  print OUT "e asm.cmtright=true\n";
  print OUT "e asm.pseudo = true\n";
#  print OUT "e cmd.stack = true\n";
  print OUT "e scr.utf8 = true\n";
  print OUT "CCa 0 \"Firmware_Identifier\"\n";
  print OUT "CCa 0x55 \"Firmware-Compilation in BCD format\" \n";
  print OUT "CCa 0x1fc \"Checksum\"\n";
  print OUT "S 0 0 256 256 Header r\n";
  print OUT "S 256 256 256 256 Sections r\n";
  print OUT "Cd 256 \@0x0\n";
  print OUT "Cd 256 \@0x100\n";
  print OUT "e bin.rawstr=true\n";
  print OUT "f SectionHeader \@ 0\n";
  print OUT "f SectionSectionList \@ 0x100\n";

  open P,">:raw","$fn.Pheader.dat";
  print P substr($content,0,512);
  close P;
  
  open I,">$fn.html";
  print I "<html><head><title>$fn analysis</title></head><body>";
  print I "Memory:<br/>";
  print I "<table border='0'><tr><td>";
  print I "Readable memory regions:<br/><img id='imageview' src='ssd.png' style='border:0px solid #80ff80' width='256' height='256'><br/>";
  print I "</td><td>";
  print I "<br/>Continuous Memory Dump Sections:<table border='1' cellspacing='0' cellpadding='2' style='border-collapse: collapse;'>";
  print I "<tr><td>ID</td><td>Start</td><td>Size</td><td>Short</td><td>Bytes</td><td>Writeable</td><td>Readonly</td><td>Comments</td></tr>";
  $pos=0;
  my $start=0;
  my $size=0;
  my $rangeid=0;
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
	  $rangeid++;
      my $short=$size/0x10000;
      my $sizex=sprintf("%08X",$size);
      my $bytes=sayBytes($size);
	  
	  push @ranges,"R$rangeid,0x$start,0x$poslx,$size,$bytes";

      open RO,"<readonly.txt";
      $/="\n";
      my $writeable=0;
      my $nonwriteable=0;
      my $startint=hex($start);
      while(<RO>)
      {
        #print "$_\n";
        if(m/Address (\d+) is (\w+)/)
        {
          my $adr=$1;
          my $write=$2;
          if(($adr>=$startint) && $adr<($startint+$size))
          {
            #print "$1 $2\n";
            $nonwriteable++ if($write eq "NOT");
            $writeable++ if($write eq "WRITEABLE");
          }
        }
      }
      close RO;


      print I "<tr onmouseover='javascript:imageview.src=\"image$start.png\"'>";
	  print I "<td>R$rangeid</td><td><a href='area.php?addr=$start'>$start</a></td><td>$sizex</td><td align='right'>$short</td><td align='right'>$bytes</td><td>$writeable</td><td>$nonwriteable</td><td>".($comment{$start}||"")."</td></tr>";
      print "Section: start=$start size=$sizex blocks=".sprintf("%4d",$short)." ".sprintf("%7s",$bytes)." rw:$writeable ro:$nonwriteable\n";
      

      open IMG,">image$start.pnm";
      print IMG "P3\n256 256\n256\n";
      foreach my $y (0 .. 255)
      {
        foreach my $x (0 .. 255)
        {
          my $pos=($y<<24)+($x<<16);
          my $fn=sprintf("ssdgood/mem0x%X",$pos);
          #print "$fn\n";
          my $v=$bgcolor;
          if(-f $fn)
          {
            $v=$existcolor if(-s $fn);
          }
          if($pos>=hex($start) && $pos<(hex($start)+$size))
          {
            $v=$markedcolor;
          }
          print IMG $v;
        }
        print IMG "\n";
      }
      close IMG;

      system "\"$imagemagick"."convert\" image$start.pnm image$start.png";
      unlink "image$start.pnm";
      $size=0;
    }
    $size+=$s;
  
    $pos+=0x10000;
  }
  print I "</table>";

  print I "</td></tr></table>";  
  
  print I "<table border='0'><tr><td valign='top'>Firmware Sections:<br/>\n";
  print I "<table border='1' bordercolor='#808080' cellspacing='0' cellpadding='2' style='border-collapse: collapse;'>";
  print I "<tr><td>Partition</td><td>Start</td><td>Map</td><td>Size</td><td>Size</td>";
  foreach(0 .. scalar(@list)-1)
  {
    print I "<td>$list[$_]</td>";
  }
  print I "</tr>";
  print I "<tr><td>Phead</td><td align='right'>0</td><td>N/A</td><td align='right'>512</td><td align='right'>0,5KB</td></tr>\n";
  
  my $end=0;
  my $pos=0x100;
  my $p=0;
  my $last=0;
  while(!$end)
  {
    $p++;
    my $n=unpack("V",substr($content,$pos,4));
    last if(!$n);
    print sprintf("Counter: %02X\n",$n);
    $pos+=4;
    foreach $sub(1 .. $n)
    {
      my $t=unpack("V",substr($content,$pos,4));
      print sprintf("t:%02X ",$t);
      $pos+=4;
      my $start=unpack("V",substr($content,$pos,4))+0x200;
      print sprintf("start:%8X ",$start);
      $pos+=4;
      my $size=unpack("V",substr($content,$pos,4));
      print sprintf("size:%8X ",$size);
      $pos+=4;
      my $map=unpack("V",substr($content,$pos,4));
      print sprintf("map:%08X\n",$map);
      $pos+=4;

      my $rwx=$sub>1?"rw":"rx";
      print OUT "S $start $map $size $size P$p$sub $rwx\n";
      print OUT "f SectionP$p$sub \@ $start\n";
      print OUT "Cd $size \@$start\n" if($rwx eq "rw");
      $last=$start+$size if($start+$size>$last);
      my @dat=();
      $dat[0]=substr($content,$start,$size);
      
      open P,">:raw","$fn.P$p$sub.frmw";
      print P $dat[0];
      close P;
      
      foreach(0 .. scalar(@list)-1)
      {
        $dat[$_+1]=loadMemory("ssd".$list[$_],$map,$size)||"";
        open P,">:raw","$fn.P$p$sub.".$list[$_];
        print P $dat[$_+1];
        close P;
      }

      my $mapx=sprintf("0x%X",$map);
      
      my @diff=();
      foreach (0 .. scalar(@list)-1)
      {
         $diff[$_]=0;
      }
        
      foreach my $pos (0 .. length($dat[0]))
      {
        foreach (0 .. scalar(@list)-1)
        {
          $diff[$_]++ if(substr($dat[0],$pos,1) ne (length($dat[$_+1])>=$pos?substr($dat[$_+1],$pos,1):""));
        }
      }
	  
      open IMG,">imageP$p$sub.pnm";
      print IMG "P3\n256 256\n256\n";
      foreach my $y (0 .. 255)
      {
        foreach my $x (0 .. 255)
        {
          my $pos=($y<<24)+($x<<16);
          my $fn=sprintf("ssdgood/mem0x%X",$pos);
          #print "$fn\n";
          my $v=$bgcolor;
          if(-f $fn)
          {
            $v=$existcolor if(-s $fn);
          }
          if($pos>=hex($mapx) && $pos<(hex($mapx)+$size+0x10000))
          {
            $v=$markedcolor;
          }
          print IMG $v;
        }
        print IMG "\n";
      }
      close IMG;
      system "\"$imagemagick"."convert\" imageP$p$sub.pnm imageP$p$sub.png";
      unlink "imageP$p$sub.pnm";
	  
      print "Partition P$p$sub from $start mapped to $mapx size ".sprintf("%7d",$size)." DIFFERS in ".join(",",@diff)." Bytes\n";
  	  push @ranges,"P$p$sub,".sprintf("0x%08X",hex($mapx)).",".sprintf("0x%08X",hex($mapx)+$size).",$size,".sayBytes($size);
      print I "<tr onmouseover='javascript:imageview.src=\"imageP$p$sub.png\"'><td><a href='$fn.P$p$sub.html'>P$p$sub</a></td><td align='right'>$start</td><td align='right'>$mapx</td><td align='right'>$size</td><td align='right'>".sayBytes($size)."</td>";
      foreach (0 .. scalar(@list)-1)
      {
        print I "<td align='right'>".$diff[$_]."</td>";
      }
      print I "</tr>\n";
      open H,">$fn.P$p$sub.html";
      print H "<html><head><title>P$p$sub analysis</title></head><body>";
      
      my @b=();
      
      foreach my $pos (0 .. length($dat[0])-1)
      {
        
        foreach (0 .. scalar(@list))
        {
          #print "pos: $pos _: $_\n";
          $b[$_].=sprintf("%6X",$_)." ".($_?$list[$_-1]:"firmware")."<br/>"if(!$pos);
          my $e=length($dat[$_])>=$pos?substr($dat[$_],$pos,1):"\x00";
          my $d=(substr($dat[0],$pos,1) ne $e);
          my $v=sprintf("%02X",unpack("C",$e),0);
          $b[$_].="<br/>".sprintf("%6X ",$pos) if(!($pos&7));
          $b[$_].=$d?"<font color='#ff0000'>$v</font> ":"$v ";
        }
      }
      print H "Differences between Firmware and Memory Dumps<br/>";
      print H "<table border='1'><tr>";
      foreach (0 .. scalar(@list))
      {
        print H "<td><font face='Courier New'>".$b[$_]."</font></td>";
      }
      print H "</tr></table>";
      print H "</body></html>";
      
      close H;
      
    }

  }
  print I "<tr><td>Ptail</td><td align='right'>1032192</td><td>N/A</td><td align='right'>".(length($content)-$last)."<td align='right'>".sayBytes((length($content)-$last))."</td></tr>\n";
  print I "</table></td><td valign='top'>\n";
  print I "CPU Cores:<br/><table border='1' bordercolor='#808080' cellspacing='0' cellpadding='2' style='border-collapse: collapse;'>";
  
  foreach(1 .. 3)
  {
    print I "<tr><td><a href='mex$_.htm'>mex$_</a></td>";
	print I "<td onmouseover='javascript:imageview.src=\"imageRmex$_.png\"'>R</td>";
	print I "<td onmouseover='javascript:imageview.src=\"imageWmex$_.png\"'>W</td>";
	print I "<td onmouseover='javascript:imageview.src=\"imageXmex$_.png\"'>X</td>";
	print I "</tr>";
  }
  print I "</table></td></tr></table>";
  
  open P,">$fn.Prest.dat";
  print P substr($content,$last);
  close P;
  
  print "Rest: ".(length($content)-$last)." Bytes\n";

  print "\n";

  my $arm=$fn; $arm=~s/\.dec/.arm/;
  if(open INA,"<$arm")
  {
    $/="\n";
    while(<INA>)
    {
      #print $_;
      print OUT "af+ $1 0 fn$1\n" if(m/\d+\s+(0x\w+)\s+/);
    }
    close INA;
  }

  close OUT;
  open OUT,">$fn.sh";
  print OUT "#!/bin/bash\n";
  print OUT "r2 -a arm -b 32 -i $fn.r2 $fn\n";
  close OUT;
  chmod 0755,"$fn.sh";
  
  
  
  print I "</body></html>";
  close I;
  
  open R,">ranges.txt";
  print R join("\n",@ranges);
  close R;
  
}


