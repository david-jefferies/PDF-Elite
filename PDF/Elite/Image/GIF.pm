#
# PDF::Elite::Image::GIF
# This module reads GIF files and saves them as readable data on the PDF, that can be used to add to pages.
#
# Copyright 2012 David Jefferies <hyperion.nz@gmail.com>.
#
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

package PDF::Elite::Image::GIF;

use strict;
use vars qw(@ISA @EXPORT $VERSION);
use Exporter;

@ISA     = qw(Exporter);
@EXPORT  = qw();
$VERSION = 0.01;

sub new {
  my $self = shift;
  my $page = shift;
  my $p = shift;
  my %params = %$p;

  my $class = ref($this) || $this;
  my $self = {};
  bless($self, $class);

  $self->{fh} = IO::File->new;
  open($self->{fh}, $params{file});
  binmode($self->{fh}, ':raw');
  read($self->{fh}, $self->{buffer}, 6); # signature
  return if $self->{buffer} !~ /^GIF[0-9][0-9][a-b]/;

  read_file($self);

  $self->{filters} = 'FlateDecode';

  #return $self;
}

sub read_file {
  my $self = shift;

  read($self->{fh}, $self->{buffer}, 7); # logical descr.
  my($widthb, $heightb, $flags, $bgColorIndex, $aspect)=unpack('vvCCC', $self->{buffer});
  while(!$self->{fh}->eof) {
    my $inter = 0;
    $self->{fh}->read($self->{buffer},1); # tag.
    my $sep=unpack('C',$self->{buffer});
    if($sep==0x2C){
      $self->{fh}->read($self->{buffer}, 9); # image-descr.
      my ($left, $top, $width, $height, $flags)=unpack('vvvvC', $self->{buffer});
      $self->{width} = $width || $widthb;
      $self->{height} = $height || $heightb;
      $self->{bpc} = 8;
      $self->{colorspace} = 'DeviceRGB';
      if($flags&0x40) {
        $inter = 1;
      } else {
        $inter = 0;
      }
      read($self->{fh}, $self->{buffer}, 1);
      my $sep = unpack('C', $self->{buffer});
      read($self->{fh}, $self->{buffer}, 1);
      my $sep = unpack('C', $self->{buffer});

      read($self->{fh}, $self->{buffer}, 1);
      my $len = unpack('C', $self->{buffer});
      my $stream='';
      while($len > 0) {
        read($self->{fh}, $self->{buffer}, $len);
        $stream .= $self->{buffer};
        read($self->{fh}, $self->{buffer}, 1);
        $len=unpack('C', $self->{buffer});
      }
      $self->{stream} = deGIF($sep + 1, $stream);
      print $self->{stream};
      #$self->unInterlace if($inter == 1);
      #last;
    }
  }

  return $self;
}

sub deGIF {
    my ($ibits,$stream)=@_;
    my $bits=$ibits;
    my $resetcode=1<<($ibits-1);
    my $endcode=$resetcode+1;
    my $nextcode=$endcode+1;
    my $ptr=0;
    my $maxptr=8*length($stream);
    my $tag;
    my $out='';
    my $outptr=0;

 #   print STDERR "reset=$resetcode\nend=$endcode\nmax=$maxptr\n";

    my @d=map { chr($_) } (0..$resetcode-1);

    while(($ptr+$bits)<=$maxptr) {
        $tag=0;
        foreach my $off (reverse 0..$bits-1) {
            $tag<<=1;
            $tag|=vec($stream,$ptr+$off,1);
        }
    #    foreach my $off (0..$bits-1) {
    #        $tag<<=1;
    #        $tag|=vec($stream,$ptr+$off,1);
    #    }
    #    print STDERR "ptr=$ptr,tag=$tag,bits=$bits,next=$nextcode\n";
    #    print STDERR "tag to large\n" if($tag>$nextcode);
        $ptr+=$bits;
        $bits++ if($nextcode == (1<<$bits));
        if($tag==$resetcode) {
            $bits=$ibits;
            $nextcode=$endcode+1;
            next;
        } elsif($tag==$endcode) {
            last;
        } elsif($tag<$resetcode) {
            $d[$nextcode]=$d[$tag];
            $out.=$d[$nextcode];
            $nextcode++;
        } elsif($tag>$endcode) {
            $d[$nextcode]=$d[$tag];
            $d[$nextcode].=substr($d[$tag+1],0,1);
            $out.=$d[$nextcode];
            $nextcode++;
        }
    }
    return($out);
}

1;