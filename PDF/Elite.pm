#
# PDF::Elite
# This module is used for creating the initial PDF structure.
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

package PDF::Elite;

#use 5.014002;
use strict;
use warnings;
use feature('switch');
use Compress::Zlib qw();

use PDF::Elite::Page;
use PDF::Elite::Font;

require Exporter;

our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();
our $VERSION = '0.01';

sub new {
  my $this = shift;
  my %params = @_;
  
  my $class = ref($this) || $this;
  my $self = {};
  bless($self, $class);

  $self->{pdf} = $self;
  $self->{version} = $params{version} || $VERSION;
  $self->{creator} = $params{creator} || 'PDF::Elite';
  $self->{author} = $params{author} || 'John Doe';
  $self->{producer} = $params{producer} || 'PDF::Elite version ' . $self->{version};
  $self->{title} = $params{title} || 'New Document';
  $self->{compress} = $params{compress} || 0;
  $self->{unit} = $params{unit} || 'point';
  $self->{marginX} = $params{marginX} || 0;
  $self->{marginY} = $params{marginY} || 0;
  $self->{textStyle} = $params{textStyle} || 0;
  $self->{mediabox} = $self->get_page_size($params{mediabox} || "A4");
  
  $self->{innerData} = '';
  $self->{xref} = 0;
  $self->{startcrossref} = 0;
  $self->{pagenumber} = 0;
  $self->{reservations}{nextAvailable} = 1;
  $self->{xref_obj} = {};
  $self->{pages} = {};
  $self->{images} = {};
  $self->{fonts} = {};

  return $self;
}

sub image {
  my $self = shift;
  my %params = @_;
  
  return if !defined $params{file} || !-e $params{file};
  my $count = scalar(keys $self->{images}) + 1;
  if ($params{file} =~ /.jpg$/ || $params{file} =~ /.jpeg$/) {
    require PDF::Elite::Image::JPEG;
    $self->{images}{$count} = new PDF::Elite::Image::JPEG($self, \%params);
  } elsif ($params{file} =~ /.gif$/) {
    require PDF::Elite::Image::GIF;
    my $obj = new PDF::Elite::Image::GIF($self, \%params);
  } else {
    die "The image " . $params{file} . " is not supported.";
  }
  if (defined $self->{images}{$count}) {
    my $num = $self->{reservations}{nextAvailable};
    $self->{reservations}{nextAvailable}++;
    $self->{images}{$count}->{objnum} = $num;
  }

  return $self->{images}{$count};
}

sub new_page {
  my $self = shift;

  $self->{pagenumber}++;
  my $num = $self->{pagenumber};

  $self->{pages}{$num} = new PDF::Elite::Page(id=>$num, pdf=>$self);

  return $self->{pages}{$num};
}

sub font {
  my ($self, $font) = @_;

  my $Fontid = $self->{reservations}{nextAvailable};
  $self->{reservations}{nextAvailable}++;

  my $count = scalar(keys $self->{fonts}) + 1;

  $self->{fonts}{$count} = new PDF::Elite::Font(number => $Fontid, font => $font);

  return $self->{fonts}{$count};
}

sub saveAs {
  my $self = shift;
  my $file = shift;

  if (scalar(keys $self->{pages}) > 0) {
    $self->version();
    $self->page_stream();
    $self->page_images();
    $self->catalog();
    $self->pages();
    $self->use_fonts();
    $self->info();
    $self->xref();
    $self->trailer();

    if (open (FILE, ">", $file)) {
      binmode(FILE);
      print FILE $self->{innerData};
      close FILE;
    } else {
      print $!;
    }
  } else {
    print "There needs to be at least 1 page in the PDF";
  }

  return $self;
}

sub convert_to_Points {
  my $self = $_[0];
  my $val = $_[1];

  given ($self->{unit}) {
    when ('cm') {
      $val = $val * 28.3464567;
    }
    when ('mm') {
      $val = $val * 2.83464567;
    }
    when ('in') {
      $val = $val * 72;
    }
    when ('point') {
      $val = $val;
    }
    default {
      $val = $val;
    }
  }
  return $val;
}

sub convert_from_Points {
  my $self = $_[0];
  my $val = $_[1];
  given ($self->{unit}) {
    when ('cm') {
      $val = $val / 28.3464567;
    }
    when ('mm') {
      $val = $val / 2.83464567;
    }
    when ('in') {
      $val = $val / 72;
    }
    when ('point') {
      $val = $val;
    }
    default {
      $val = $val;
    }
  }

  return $val;
}

sub version {
  my $self = shift;

  $self->add( "%PDF-" . $self->{version} . "\n" );

  return $self;
}

sub page_stream {
  my $self = shift;
  
  my $objs = '';
  my $size = 0;
  my $counter = 1;
  my $currentkey;

  foreach my $key(sort {$a<=>$b} keys $self->{pages}) {
    $currentkey = $key;
    my $b = scalar(keys $self->{pages}{$key}->{objects});
    $objs .= $self->{pages}{$key}->stream_output();
    $size = length($objs);
    if ($size > 0) {
      my $obj = "/Length " . $size . "\n";
         $obj .= "/Filter [/FlateDecode]\n" if $self->{compress} == 1;
         $obj .= ">>\nstream\n";
         $obj .= $objs if $self->{compress} != 1;
         $obj .= Compress::Zlib::compress($objs) if $self->{compress} == 1;
         $obj .= "endstream\n";
      my $num = $self->{reservations}{nextAvailable};
      $self->{reservations}{nextAvailable}++;
      $self->{pages}{$key}->{contents}{1}->{num} = $num;
      $self->add_Obj(id=>$num, data=>$obj);
      my $annot = '';
      foreach my $link (keys %{$self->{pages}{$key}{objects}}) {
        if ($self->{pages}{$key}{objects}{$link}->{type} eq 'text') {
          if ($self->{pages}{$key}{objects}{$link}->{link}->{exists} eq 'Y') {
            my $num1 = $self->{reservations}{nextAvailable};
            $self->{reservations}{nextAvailable}++;
            my $n = scalar(keys %{$self->{pages}{$key}->{annots}});
            #$self->{pages}{$key}->{annots}{$n}->{num} = $num1;
            $self->add_Obj(id=>$num1, data=>$self->{pages}{$key}{objects}{$link}->{link}->{stream});
            $annot .= "$num1 0 R ";
          }
        }
      }
      $self->{pages}{$key}->{annots}{1}->{num} = $annot;
    }
    my $num = $self->{reservations}{nextAvailable};
    $self->{reservations}{nextAvailable}++;
    $self->{pages}{$key}->{pageid} = $num;
    $size = 0;
    $objs = '';
    $counter = 1;
  }
  if ($objs ne '') {
    $size = length($objs);
    if ($size > 0) {
      my $obj = "/Length " . $size . "\n";
         $obj .= "/Filter [/FlateDecode]\n" if $self->{compress} == 1;
         $obj .= ">>\nstream\n";
         $obj .= $objs if $self->{compress} != 1;
         $obj .= Compress::Zlib::compress($objs) if $self->{compress} == 1;
         $obj .= "endstream\n";
      my $num = $self->{reservations}{nextAvailable};
      $self->{reservations}{nextAvailable}++;
      $self->{pages}{$currentkey}->{contents}{1}->{num} = $num;
      $self->add_Obj(id=>$num, data=>$obj);

      my $cnum = $self->{reservations}{nextAvailable};
      $self->{reservations}{nextAvailable}++;
      $self->{pages}{$currentkey}->{pageid} = $cnum;
    }
  }

  return $self;
}

sub page_images {
  my $self = shift;
  
  foreach my $key(sort {$a<=>$b} keys $self->{images}) {
    next if !defined $self->{images}{$key}->{stream};
    my $data = $self->{images}{$key}->{stream};

    my $obj = $self->{images}{$key}->{objnum} . " 0 obj\n" .
              "<<\n" .
              "/DecodeParms [<<\n" .
              ">>]\n" .
              "/Height " . $self->{images}{$key}->{height} . "\n" .
              "/Width " . $self->{images}{$key}->{width} . "\n" .
              "/ColorSpace [/" . $self->{images}{$key}->{colorspace} . "]\n" .
              "/Length " . $self->{images}{$key}->{length} . "\n" .
              "/Filter [/" . $self->{images}{$key}->{filters} . "]\n" .
              "/Type /XObject\n" .
              "/BitsPerComponent " . $self->{images}{$key}->{bpc} . "\n" .
              "/Subtype /Image\n" .
              "/Name /Image" . $self->{images}{$key}->{objnum} . "\n" .
              ">>\n";
    $self->add($obj);
    $obj = "stream\n" .
           $data . "\n" .
           "endstream\n\n" .
           "endobj\n\n";
    $self->add($obj);
  }

  return $self;
}

sub catalog {
  my $self = shift;
  
  $self->{reservations}{catalog} = $self->{reservations}{nextAvailable};
  $self->{reservations}{nextAvailable}++;
  $self->{reservations}{pagesOverview} = $self->{reservations}{nextAvailable};
  $self->{reservations}{nextAvailable}++;
  $self->{reservations}{info} = $self->{reservations}{nextAvailable};
  $self->{reservations}{nextAvailable}++;
  
  my $obj = "/Type /Catalog\n" .
            "/Pages " . $self->{reservations}{pagesOverview} . " 0 R\n" .
            "/PageMode /UseOutlines\n";
  $self->add_Obj(id=>$self->{reservations}{catalog}, data=>$obj);

  return $self;
}

sub pages {
  my $self = shift;

  my $kids = '';
  my $counter = 0;
  my $total = 0;
  my $currentkey;
  foreach my $key(sort {$a<=>$b} keys $self->{pages}) {
    $counter++;
    $currentkey = $key;

    $kids .= ' ' if $kids ne '';
    $kids .= $self->{pages}{$currentkey}->{pageid} . ' 0 R';
    $counter = 0;
    $total++;

    my ($proc, $cont) = '';
    my $font = $self->get_page_font($currentkey);
    my $content = '';
    my $annots = '';
    if (scalar(keys %{$self->{pages}{$currentkey}->{contents}}) >= 1) {
      $content = '/Contents ' . $self->{pages}{$currentkey}->{contents}{1}->{num} . " 0 R\n";
    }
    if (scalar(keys %{$self->{pages}{$currentkey}->{annots}}) >= 1) {
      $annots = '/Annots [ ' . $self->{pages}{$currentkey}->{annots}{1}->{num} . "]\n";
    }
    my $obj = "/Type /Page\n" .
              "/MediaBox " . $self->{mediabox} . "\n" .
              "/Parent " . $self->{reservations}{pagesOverview} . " 0 R\n" .
              $font . $content . $annots;
    $self->add_Obj(id=>$self->{pages}{$currentkey}->{pageid}, data=>$obj);
  }

  my $obj = "/Kids [" . $kids . "]\n" .
            "/Type /Pages\n" .
            "/Count " . $total . "\n";
  $self->add_Obj('id'=>$self->{reservations}{pagesOverview}, 'data'=>$obj);

  return $self;
}

sub use_fonts {
  my $self = shift;

  foreach my $key(sort keys $self->{fonts}) {
    my $obj = "/Type /Font\n" .
           "/Subtype /" . $self->{fonts}{$key}->{Subtype} . "\n" . 
           "/Name /" . $self->{fonts}{$key}->{FontName} . "\n" .
           "/BaseFont /" . $self->{fonts}{$key}->{BaseFont} . "\n" . 
           "/Encoding /WinAnsiEncoding\n";
    $self->add_Obj(id=>$self->{fonts}{$key}->{Fontid}, data=>$obj);
  }

  return $self;
}

sub info {
  my $self = shift;

  my $producer = $self->{producer};
  my $author = $self->{author};
  my $title = $self->{title};
  my $creator = $self->{creator};

  my $obj = "/Type /Info\n" .
            "/Producer ($producer)\n" .
            "/Author ($author)\n" .
            "/Title ($title)\n";

  $self->add_Obj('id'=>$self->{reservations}{info}, 'data'=>$obj);

  return $self;
}

sub xref {
  my $self = shift;

  $self->{startcrossref} = 1;

  my $obj = "xref\n" .
            "0 " . $self->{reservations}{nextAvailable} . "\n" .
            "0000000000 65535 f \n";
  foreach my $value(sort {$a<=>$b} keys $self->{xref_obj}) {
    $obj .= $self->{xref_obj}{$value} . " \n";
  }

  $self->add($obj);

  return $self;
}

sub trailer {
  my $self = shift;

  my $obj = "trailer\n<<\n" .
            "/Size " . $self->{reservations}{nextAvailable} . "\n" .
            "/Root " . $self->{reservations}{catalog} . " 0 R\n" .
            "/Info " . $self->{reservations}{info} . " 0 R\n" .
            ">>\nstartxref\n" .
            $self->{xref} .
            "\n%%EOF\n";
  $self->add($obj);

  return $self;
}

sub add_Obj {
  my $self = shift;
  my %params = @_;

  $self->add($params{id} . " 0 obj\n<<\n");
  $self->add($params{data});
  $self->add(">>\nendobj\n\n");

  return $self;
}

sub add {
  my $self = shift;
  my $data = join '', @_;

  $self->{innerData} .= $data;
  if ($data =~ /obj\n<</) {
    my @a = split(/\s0\sobj\n<<\n/, $data);
    $self->{xref_obj}{$a[0]} = sprintf("%010s", $self->{xref}) . ' 00000 n';
  }
  if ($self->{startcrossref} == 0) {
    $self->{xref} += length($data);
  }

  return $self;
}

sub get_page_size {
  my $self = shift;
  my $name = uc(shift);

  my %pagesizes = ( 'A0'         => '[0 0 2380 3368]',
                    'A1'         => '[0 0 1684 2380]',
                    'A2'         => '[0 0 1190 1684]',
                    'A3'         => '[0 0 842 1190]',
                    'A4'         => '[0 0 595 842]',
                    'A4L'        => '[0 0 842 595]',
                    'A5'         => '[0 0 421 595]',
                    'A6'         => '[0 0 297 421]',
                    'LETTER'     => '[0 0 612 792]',
                    'BROADSHEET' => '[0 0 1296 1584]',
                    'LEDGER'     => '[0 0 1224 792]',
                    'TABLOID'    => '[0 0 792 1224]',
                    'LEGAL'      => '[0 0 612 1008]',
                    'EXECUTIVE'  => '[0 0 522 756]',
                    '36X36'      => '[0 0 2592 2592]',
  );

  if ( !$pagesizes{$name} ) {
    $name = "A4";
  }

  return $pagesizes{$name};
}

sub get_page_font {
  my $self = shift;
  my $key = shift;

  my $ret = '';
  $ret = "/Resources <<\n" .
         "/Font << \n";
  foreach my $k(sort keys $self->{fonts}) {
    $ret .= "/" . $self->{fonts}{$k}->{FontName} . " " .
    $self->{fonts}{$k}->{Fontid} . " 0 R \n";
  }
  $ret .= ">> \n" .
          "/XObject << \n";
  my $c = scalar(keys $self->{images});
  for (my $a = 1; $a <= $c; $a++) {
    my $objnum = $self->{images}{$a}->{objnum};
    $ret .= "/Image" . $objnum . " " . $objnum . " 0 R \n";
  }
  $ret .= ">>\n" .
          "/ProcSet [/PDF]\n>>\n";

  return $ret;
}

1;
__END__

=head1 NAME

PDF::Elite - Create PDF Files.

=head1 SYNOPSIS

Create PDF files from your perl program, using subroutines to handle fonts, drawing primitives, images, text, 
filled blocks, and boxes.

This module is written in pure Perl, and only has couple of dependencies (FileHandler, Compress::Zlib, Feature).  This
module is not platform dependant.

This module was specifically designed to handle complex PDFs.  No understanding of the underlying Postscript/PDF format 
is necessary, as all the complex methods etc are all built in to the modules to make life simple.

Example PDF creation using C<PDF::Elite>:

  use PDF::Elite;

  #create the PDF
  my $pdf = new PDF::Elite();

  #Add a page to the PDF
  $page = $pdf->new_page();

  #add a font to the pdf
  $font = $pdf->font('timesbold');

  #add a text element to the page.  This must include text parameter and a font parameter.
  my ($l, $b, $r, $t) = $page->add_Text(font => $font, text => "This is a wrapping test\n\nThis is a second wrapping test", 
                                        valign => 2, xpos => 100, ypos => 300, maxWidth => 100, textStyle => 2);
  $page->add_Text(font => $font, text => 'Test me', xpos => $r, ypos => $b, maxWidth => 30);

  #add a box to the page.  If it has a color parameter then it is just a box with no color filled in.
  $page->add_Box(color => 'black', xpos => 100, ypos => 100, width => 50, height => 100);

  #add a box to the page.  If it has a fill parameter then it is just a box with color filled in.
  $page->add_Box(fill => 'yellow', xpos => 220, ypos => 100, width => 100, height => 100);

  #add an image to the PDF.
  my $img = $pdf->image(file => 'logo.jpg');

  #use the image on the page
  $page->add_Image(image => $img, height => 100);

  #save the PDF as a file.
  $pdf->saveAs('Test.pdf');


=head1 DESCRIPTION

Create PDF files from your perl program, using subroutines to handle fonts, drawing primitives, images, text,
filled blocks, and boxes.

PDF stands for Portable Document Format.

Documents can have as many pages, and a number of different elements.  Due this being the first release of this
project, there are only a few elements for now.  More will be added in future releases.

=head1 METHODS

U<PDF element>

=item new

Creates the PDF structure.
B<New Page Options:>

=over

=item version

The version that you wish to use for this PDF.  if no version is supplied the version number of PDF::Elite is used.

=item creator

The name of the creator.  If no creator option is supplied then PDF::Elite is used as the creator.

=item author

The name of the author.  If no author is supplied then it will default to 'John Doe'.

=item producer

The name of the producer.  If no producer is supplied then the default is used 'PDF::Elite version 0.01'.

=item title

The title of the PDF document.  If no title is supplied then the default 'New Document' is used.

=item compress

Whether or not you wish the streams to be compressed or not.  If not supplied then the default(1) will be used.
  0 = Not compressed
  1 = Compressed

=item unit
  
  The unit of measure you wish to use.  This is handy if you are working of a design plan, that you have measurements
  on.  If no unit is supplied then it defaults to 'point'.  
  The other units you can use are:
    cm = centimeters
    mm = milimeters
    in = inches

=item marginX

  The margin for the left and right side of the page.  If not supplied then it defaults to 0.
  
=item marginY

  The margin for the top and bottom of the page.  If not supplied then it defaults to 0.
  
=item textStyle

  How you wish the default text elements to behave.
    0 = Hscaled to fit
    1 = shrink to fit
    2 = text wraps.
    
=item mediabox

  The size you wish the pages to be.  If not supplied then it will default to A4.
  
=back

=item image

  Creates the image stream that can be used on pages.  Currently only JPEG images are supported.
  
=item font

  Creates a font element that can be used for text streams on a page.
  usage:  $pdf->font('timesbold');
  - courier
  - courierbold
  - courierboldoblique
  - courieroblique
  - helvetica
  - helveticabold
  - helveticaboldoblique
  - heliveticaoblique
  - times
  - timesbold
  - timesbolditalic
  - timesitalic
  
=item new_page

  Creates a new page on the pdf using the options specified when creating the pdf.
  
  
U<Page element>

=item add_Text

  Adds Text to the current page.

  B<Text Options:>
  
=over

=item font

  This must be specified and is the font that was created on the PDF structure.
  
=item fontSize

  Specifies the size you want the font to be.  If not specified then it defaults to 12.
  
=item color

  Specifies the color for the text.
  - black
  - blue
  - lime
  - aqua
  - red
  - pink
  - yellow
  - white
  - gray
  - custom (if this is used for the color then the custom attribute also needs to be used.)
  
=item custom

  Only used if the color is custom.  This is a RGB value i.e. standard yellow is 1 1 0 lighter shade of yellow could be 1 1 0.5
  
=item xpos

  Specifies the horizontal left position of the text.
  
=item ypos

  Specifies the vertical bottom position of the text.
  
=item text

  The text you wish to display on the PDF.
  
=item textStyle
  
  How you wish this text to behave.
    0 = Hscaled to fit
    1 = shrink to fit
    2 = text wraps.
    
=item maxWidth

  The width you wish the text to be.  This is handy for complex PDFs that require alot of text bunched together.  If the 
  text width is greater than the maxWidth then it alters the text field to whatever the textStyle is.



=head1 AUTHOR

David Jefferies

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by David Jefferies

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
