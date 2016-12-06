my @list=(   # 2^37/(16+n)
  4042322160, # 0xF0F0F0F0
  3817748707, # 0xE38E38E3
  3616814565, # 0xD79435E5
  3435973836, # 0xCCCCCCCC
  3272356035, # 0xC30C30C3
  3123612578, # 0xBA2E8BA2
  2987803336, # 0xB21642C8
  2863311530, # 0xAAAAAAAA
  2748779069, # 0xA3D70A3D
  2643056797, # 0x9D89D89D 
  2545165805, # 0x97B425ED
  2454267026, # 0x92492492
  2369637128, # 0x8D3DCB08
  2290649224, # 0x88888888
  2216757314, # 0x84210842
  2147483648  # 0x80000000
);

my $old=1;
foreach(@list)
{
  my $d=(0x1000000000/$_);
  print "$_: $d ".($d-$old)."\n";
  $old=$d;
}

foreach(0 .. 15)
{
  print "$_: ".(2**36 / (17+$_))."\n";
}