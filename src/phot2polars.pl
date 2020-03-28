#!/usr/bin/perl -w

use strict;
use Getopt::Long ;
use Pod::Usage ;

# Help section
my $help ;
my $man ;
# File output section
my $outputname ;
# Table processing section
our $trim = 1 ;
our $delimiter = ',' ;
our $empty = 99.9900 ;
# FITS file
our $fitsprefix = '../fits/' ;


GetOptions( 
'help|?' => \$help,
'manual|man' => \$man,
'output|o=s' => \$outputname,
'trim!' => \$trim,
'delimiter=s' => \$delimiter,
'empty=s' => \$empty,
'fitsprefix=s' => \$fitsprefix,
) || pod2usage( -verbose => 0, -exitval => 2 ) ;

pod2usage( -verbose => 1, -exitval => 0 )       if $help ;
pod2usage( -verbose => 2, -exitval => 0 )       if $man ;



my ($filename) = @ARGV ;



open( my $file, '<', $filename ) 
  || die("Data file <$filename> can not be opened") ;

$delimiter='\|' if $delimiter=~/^\|$/;

my $output = *STDOUT ;
if ($outputname) {
  open( $output, '>', $outputname ) 
    || die("Output file <$outputname> can not be opened") ;
};


# WRITE the SQL commands

print {$output} <<EOB;
-- SQL input for $filename

BEGIN;

-------- FITS files

EOB


my @fits ;
foreach (GetFITSNames($file)) { 
  push @fits, WriteFITSInfo( $_ ) ;
} ;

WriteImportTable($file) ;
close($file) ;

WriteInsertData(@fits);


print {$output} <<EOB;

COMMIT;
EOB

close($output);






#### SUBROUTIONES ####
sub Str2Fields{
  my $str = shift ;

  my @fields = split(/$delimiter/, $str, -1) ;
  @fields = map { s/^\s*|\s*$//g; $_ } @fields  if $trim ;
  return @fields ;
};

sub GetFields{
  my $file = shift ;
  
  my $str = '' ;
  while ( !eof($file) and $str=~/^$/ ) {
    $str = <$file> ;
    chomp($str);
  };
  return Str2Fields( $str ) ;
};


sub ReplaceEmpty{
  my @f = @_ ;

  foreach (@f) {
    $_='\N' if /^\s*$/ ;
    $_='\N' if $empty && /^$empty$/ ;
  };
  return @f ;
};


sub GetFITSNames{
  my $file = shift ;
  
  my @fitsnames ;

  my $pos ;
  my $str = '' ;
  while ( !eof($file) and $str=~/(^$|^#)/ ) {
    $pos = tell($file) ;
    
    $str = <$file> ;
    chomp($str);
    
    if ($str=~/INPUT IMAGES/) {
      $str =~ s/^ *# *INPUT IMAGES *: *// ;
      @fitsnames = map { s/^\s*|\s*$//g; $_ } split(/,/, $str) ;
    };
  };
  seek( $file, $pos, 0 )  if $str=~/(^$|^#)/ ;
  
  return @fitsnames ;
};


sub GetFITSFile{
  my $fits = shift ;
  
  my $file = `find $fitsprefix -name $fits ` ;
  chomp($file);
  die "Impossible to find the FITS file = $fits\n" if !$file ;
  
  return $file
};

sub dePrefixFITSFile{
  my $name = shift;
  
  my $ind = index($name,$fitsprefix);
  my $len = length($fitsprefix);
  $name = substr( $name, $ind+$len, length($name)-$len )  if $ind>=0 && $len ;
  
  return $name ;
}

sub WriteFITSInfo{
  my $name = shift ;

  my $file = GetFITSFile($name) ;
  my $fits = dePrefixFITSFile($file) ;
  
  my $header = `imhead $file | grep =` ;

  (my $dateobs) = ($header =~ /DATE-OBS= *' *([^']+) *'*?/ );
  (my $band) = ($header =~ /FILTER *= *(\d+)/ );
  $band='SED'.$band ;
  (my $exptime) = ($header =~ /EXPTIME *= *(\d+(\.\d+)?)/ );
  (my $mjd) = ($header =~ /MJD *= *(\d+(\.\d+)?)/ );
  (my $ra)  = ($header =~ /RA *= *(\d+(\.\d+)?)/ );
  (my $dec) = ($header =~ /DEC *= *(\d+(\.\d+)?)/ );
  
  
  my @list = split("\n",$header) ;
  @list = map { s/^ *([A-Z0-9_-]+) *= *' *(.*?) *'.*$/"$1" : "$2"/g; $_ } @list ;               # quoted values
  @list = map { s/^ *(SIMPLE|EXTEND) *= *(.*?) *\/.*$/"$1" : "$2"/g; $_ } @list ;               #
  @list = map { s/^ *([A-Z0-9_-]+) *= *([+-]?\d+(\.\d+([eE][+-]?\d+)?)?) *\/.*$/"$1" : $2/g; $_ } @list ;      # numbers
  @list = map { s/^ *([A-Z0-9_-]+) *= *([+-]?\d+)\. *\/.*$/"$1" : $2/g; $_ } @list ;            # numbers as 300.
  
  $header = join("\n, ",@list) ;
  
print {$output} <<EOB;
INSERT INTO frame (frameid,dateobs,band,exptime,mjd,ra,dec,header)
VALUES
( '$fits' , '$dateobs' , '$band' , $exptime , $mjd , $ra , $dec ,
'{$header
}'::json
) ;

EOB
  
  return $fits ;
};



sub WriteImportTable{
  my $file = shift ;
  
print {$output} <<EOB;

------ Photometry Table
CREATE TEMPORARY TABLE import_table (
  "OBJ_NAME"             VarChar
, "X_IMAGE(pixels)"      Real
, "Y_IMAGE(pixels)"      Real
, "RA(ALPHAWIN_J2000)"   Double Precision
, "DEC(DELTAWIN_J2000)"  Double Precision
, "MAG_STD_470"          Real
, "MAGERR_STD_470"       Real
, "MAG_STD_540"          Real
, "MAGERR_STD_540"       Real
, "MAG_STD_656"          Real
, "MAGERR_STD_656"       Real
, "470-540"              Real
, "ERR_470-540"          Real
, "540-656"              Real
, "ERR_540-656"          Real
, "470-656"              Real
, "ERR_470-656"          Real
, "FLAG"                 SmallInt
) ;

COPY import_table FROM STDIN;
EOB

while (my $str=<$file>) {
  chomp($str);
  print {$output} join("\t", Str2Fields($str) )."\n" if $str!~/(^$|^#)/;
};

print {$output} <<'EOB';
\.

UPDATE import_table SET "MAG_STD_470"=NULL    WHERE abs("MAG_STD_470"-99.99)<=0.005 ;
UPDATE import_table SET "MAGERR_STD_470"=NULL WHERE abs("MAGERR_STD_470"-99.99)<=0.005 ;
UPDATE import_table SET "MAG_STD_540"=NULL    WHERE abs("MAG_STD_540"-99.99)<=0.005 ;
UPDATE import_table SET "MAGERR_STD_540"=NULL WHERE abs("MAGERR_STD_540"-99.99)<=0.005 ;
UPDATE import_table SET "MAG_STD_656"=NULL    WHERE abs("MAG_STD_656"-99.99)<=0.005 ;
UPDATE import_table SET "MAGERR_STD_656"=NULL WHERE abs("MAGERR_STD_656"-99.99)<=0.005 ;

UPDATE import_table SET "470-540"=NULL        WHERE abs("470-540"-99.99)<=0.005 ;
UPDATE import_table SET "ERR_470-540"=NULL    WHERE abs("ERR_470-540"-99.99)<=0.005 ;
UPDATE import_table SET "540-656"=NULL        WHERE abs("540-656"-99.99)<=0.005 ;
UPDATE import_table SET "ERR_540-656"=NULL    WHERE abs("ERR_540-656"-99.99)<=0.005 ;
UPDATE import_table SET "470-656"=NULL        WHERE abs("470-656"-99.99)<=0.005 ;
UPDATE import_table SET "ERR_470-656"=NULL    WHERE abs("ERR_470-656"-99.99)<=0.005 ;

EOB

};


sub WriteInsertData{
  my $fits470 = shift ;
  my $fits540 = shift ;
  my $fits656 = shift ;
  
print {$output} <<EOB;

------ Insert data into DB

INSERT INTO photorun VALUES (DEFAULT,NULL) ;
INSERT INTO runset VALUES 
  ( (SELECT max(runid) FROM photorun) , '$fits470' )
, ( (SELECT max(runid) FROM photorun) , '$fits540' )
, ( (SELECT max(runid) FROM photorun) , '$fits656' )
;

INSERT INTO photoobj (runid,frameid,runobjid,x,y,ra,dec,mag,e_mag,quality)
SELECT (SELECT max(runid) FROM photorun) , '$fits470' , "OBJ_NAME" , "X_IMAGE(pixels)" , "Y_IMAGE(pixels)" , "RA(ALPHAWIN_J2000)" , "DEC(DELTAWIN_J2000)" , "MAG_STD_470" , "MAGERR_STD_470" , "FLAG" 
FROM import_table 
WHERE "MAG_STD_470" IS NOT NULL ;

INSERT INTO photoobj (runid,frameid,runobjid,x,y,ra,dec,mag,e_mag,quality)
SELECT (SELECT max(runid) FROM photorun) , '$fits540' , "OBJ_NAME" , "X_IMAGE(pixels)" , "Y_IMAGE(pixels)" , "RA(ALPHAWIN_J2000)" , "DEC(DELTAWIN_J2000)" , "MAG_STD_540" , "MAGERR_STD_540" , "FLAG" 
FROM import_table 
WHERE "MAG_STD_540" IS NOT NULL ;

INSERT INTO photoobj (runid,frameid,runobjid,x,y,ra,dec,mag,e_mag,quality)
SELECT (SELECT max(runid) FROM photorun) , '$fits656' , "OBJ_NAME" , "X_IMAGE(pixels)" , "Y_IMAGE(pixels)" , "RA(ALPHAWIN_J2000)" , "DEC(DELTAWIN_J2000)" , "MAG_STD_656" , "MAGERR_STD_656" , "FLAG" 
FROM import_table 
WHERE "MAG_STD_656" IS NOT NULL ;

EOB
};
