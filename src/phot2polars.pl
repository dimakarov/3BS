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
our $empty = 99.00000 ;

# FITS file
our $fitsprefix = '../fits/' ;

# Debug section
our $debug = 0 ;


GetOptions( 
'help|?' => \$help,
'manual|man' => \$man,
'output|o=s' => \$outputname,
'trim!' => \$trim,
'delimiter=s' => \$delimiter,
'empty=s' => \$empty,
'fitsprefix=s' => \$fitsprefix,
'debug!' => \$debug,
) || pod2usage( -verbose => 0, -exitval => 2 ) ;

pod2usage( -verbose => 1, -exitval => 0 )       if $help ;
pod2usage( -verbose => 2, -exitval => 0 )       if $man ;


print "======= Debug mode =========\n"   if $debug ;

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


my $header ;
my @fits ;
foreach (GetFITSNames($file)) { 
  my $fts ;
  ($fts,$header) = GetFITSHeader( $_ ) ;
  WriteFITSInfo( $fts, $header ) ;
  push @fits, $fts ;
} ;

WriteImportTable($file) ;
close($file) ;

WritePhotoRun($header);
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


sub GetFITSHeader{
  my $name = shift ;

  my $file = GetFITSFile($name) ;
  my $fits = dePrefixFITSFile($file) ;

  my $header = `imhead $file | grep = | grep -v ^HISTORY | grep -v ^_` ;

  return ($fits,$header) ;
}

sub WriteFITSInfo{
  my $fits = shift ;
  my $header = shift ;


  (my $dateobs) = ($header =~ /DATE-OBS= *' *([^']+) *'*?/ );

  (my $band) = ($header =~ /FILTER *= *'? *(\d+)/ ) ;
  die 'Can not extract a band name from a header:'.join('',($header =~ /^(FILTER.*)$/))."\n"  if !$band ;
  $band='SED'.$band ;
  die "Unknown filter: $band\n"  if $band !~ /^SED(470|540|656)$/ ;

  (my $exptime) = ($header =~ /EXPTIME *= *(\d+(\.\d+)?)/ );
  (my $mjd) = ($header =~ /MJD *= *(\d+(\.\d+)?)/ );
  (my $ra)  = ($header =~ /RA *= *(\d+(\.\d+)?)/ );
  (my $dec) = ($header =~ /DEC *= *([+-]?\d+(\.\d+)?)/ );

  die "Can not find/decode RA field in FITS-file: $fits\n"	if ! $ra ;
  die "Can not find/decode DEC field in FITS-file: $fits\n"	if ! $dec ;
  
  
  my @list = split("\n",$header) ;
  @list = map { s/^ *([A-Z0-9_-]+) *= *' *(.*?) *'.*$/"$1" : "$2"/g; $_ } @list ;               # quoted values
  @list = map { s/^ *(SIMPLE|EXTEND) *= *(.*?) *\/.*$/"$1" : "$2"/g; $_ } @list ;               #
  @list = map { s/^ *([A-Z0-9_-]+) *= *([+-]?\d+(\.\d+([eE][+-]?\d+)?)?) *(\/.*)?$/"$1" : $2/g; $_ } @list ;      # numbers
  @list = map { s/^ *([A-Z0-9_-]+) *= *([+-]?\d+)\. *(\/.*)?$/"$1" : $2/g; $_ } @list ;            # numbers as 300.
  
  $header = join("\n, ",@list) ;
  
print {$output} <<EOB;
INSERT INTO frame (frameid,dateobs,band,exptime,mjd,ra,dec,header)
VALUES
( '$fits' , '$dateobs' , '$band' , $exptime , $mjd , $ra , $dec ,
'{$header
}'::json
) ;

EOB
};


sub WritePhotoRun{
  my $header = shift ;

  (my $objname) = ($header =~ /OBJECT *= *' *([^']+)/ );
  (my $dateobs) = ($header =~ /DATE-OBS= *' *([^']+)/ );
  (my $author)  = ($header =~ /AUTHOR *= *' *([^']+)/ );
  (my $program) = ($header =~ /PROGRAM *= *' *([^']+)/ );
  (my $tel)     = ($header =~ /TELESCOP *= *' *([^']+)/ );
  (my $observ)  = ($header =~ /OBSERVAT *= *' *([^']+)/ );

  $objname =~ s/\s+$// ;
  $objname = '"'.$objname.'" was observed' if $objname ;
  $objname = 'Observations' if !$objname ;

  $author =~ s/\s+$// ;
  $author = ' by '.$author if $author;

  $dateobs = ' on '.$dateobs if $dateobs ;

  $program =~ s/\s+$// ; 
  $program = ' in framework of the program "'.$program.'"' if $program ;

  $tel =~ s/\s+$// ;
  $tel = ' on '.$tel if $tel ;

  $observ =~ s/\s+$// ;
  $observ = 'the '.$observ if $observ && $observ!~'^ *the' ;
  $observ = $tel.' of '.$observ if $tel && $observ ;
  $observ = ' in '.$observ if $observ && !$tel ;

  print {$output} <<EOB;
------ Initialize PhotoRun

INSERT INTO photorun VALUES (DEFAULT,'$objname$dateobs$program$author$observ') ;

EOB
};





sub WriteImportTable{
  my $file = shift ;
  
print {$output} <<EOB;

------ Photometry Table
CREATE TEMPORARY TABLE import_table (
  "NAME"	VarChar
, "RA"	Double Precision
, "DEC"	Double Precision
, "MAG_STD_470"	Real
, "MAGERR_STD_470"	Real
, "MAG_STD_470_PSF"	Real
, "MAGERR_STD_470_PSF"	Real
, "MAG_STD_540"	Real
, "MAGERR_STD_540"	Real
, "MAG_STD_540_PSF"	Real
, "MAGERR_STD_540_PSF"	Real
, "MAG_STD_656"	Real
, "MAGERR_STD_656"	Real
, "MAG_STD_656_PSF"	Real
, "MAGERR_STD_656_PSF"	Real
, "470-540"	Real
, "ERR_470-540"	Real
, "470-540_PSF"	Real
, "ERR_470-540_PSF"	Real
, "540-656"	Real
, "ERR_540-656"	Real
, "540-656_PSF"	Real
, "ERR_540-656_PSF"	Real
, "470-656"	Real
, "ERR_470-656"	Real
, "470-656_PSF"	Real
, "ERR_470-656_PSF"	Real
, "CLASS_470"	Char
, "CLASS_540"	Char
, "CLASS_656"	Char
, "FLAGS_470"	SmallInt
, "FLAGS_540"	SmallInt
, "FLAGS_656"	SmallInt
) ;

COPY import_table FROM STDIN;
EOB

while (my $str=<$file>) {
  chomp($str);
  print {$output} join("\t", Str2Fields($str) )."\n" if $str!~/(^$|^#)/;
};

print {$output} <<'EOB';
\.

UPDATE import_table SET "MAG_STD_470"=NULL    WHERE abs("MAG_STD_470"-99.00)<=0.005 ;
UPDATE import_table SET "MAGERR_STD_470"=NULL WHERE abs("MAGERR_STD_470"-99.00)<=0.005 ;
UPDATE import_table SET "MAG_STD_540"=NULL    WHERE abs("MAG_STD_540"-99.00)<=0.005 ;
UPDATE import_table SET "MAGERR_STD_540"=NULL WHERE abs("MAGERR_STD_540"-99.00)<=0.005 ;
UPDATE import_table SET "MAG_STD_656"=NULL    WHERE abs("MAG_STD_656"-99.00)<=0.005 ;
UPDATE import_table SET "MAGERR_STD_656"=NULL WHERE abs("MAGERR_STD_656"-99.00)<=0.005 ;

UPDATE import_table SET "MAG_STD_470_PSF"=NULL    WHERE abs("MAG_STD_470_PSF"-99.00)<=0.005 ;
UPDATE import_table SET "MAGERR_STD_470_PSF"=NULL WHERE abs("MAGERR_STD_470_PSF"-99.00)<=0.005 ;
UPDATE import_table SET "MAG_STD_540_PSF"=NULL    WHERE abs("MAG_STD_540_PSF"-99.00)<=0.005 ;
UPDATE import_table SET "MAGERR_STD_540_PSF"=NULL WHERE abs("MAGERR_STD_540_PSF"-99.00)<=0.005 ;
UPDATE import_table SET "MAG_STD_656_PSF"=NULL    WHERE abs("MAG_STD_656_PSF"-99.00)<=0.005 ;
UPDATE import_table SET "MAGERR_STD_656_PSF"=NULL WHERE abs("MAGERR_STD_656_PSF"-99.00)<=0.005 ;


UPDATE import_table SET "470-540"=NULL        WHERE abs("470-540"-99.00)<=0.005 ;
UPDATE import_table SET "ERR_470-540"=NULL    WHERE abs("ERR_470-540"-99.00)<=0.005 ;
UPDATE import_table SET "540-656"=NULL        WHERE abs("540-656"-99.00)<=0.005 ;
UPDATE import_table SET "ERR_540-656"=NULL    WHERE abs("ERR_540-656"-99.00)<=0.005 ;
UPDATE import_table SET "470-656"=NULL        WHERE abs("470-656"-99.00)<=0.005 ;
UPDATE import_table SET "ERR_470-656"=NULL    WHERE abs("ERR_470-656"-99.00)<=0.005 ;

UPDATE import_table SET "470-540_PSF"=NULL        WHERE abs("470-540_PSF"-99.00)<=0.005 ;
UPDATE import_table SET "ERR_470-540_PSF"=NULL    WHERE abs("ERR_470-540_PSF"-99.00)<=0.005 ;
UPDATE import_table SET "540-656_PSF"=NULL        WHERE abs("540-656_PSF"-99.00)<=0.005 ;
UPDATE import_table SET "ERR_540-656_PSF"=NULL    WHERE abs("ERR_540-656_PSF"-99.00)<=0.005 ;
UPDATE import_table SET "470-656_PSF"=NULL        WHERE abs("470-656_PSF"-99.00)<=0.005 ;
UPDATE import_table SET "ERR_470-656_PSF"=NULL    WHERE abs("ERR_470-656_PSF"-99.00)<=0.005 ;


UPDATE import_table
SET "NAME" = t."NAME"||chr(64+t.n::SmallInt)
FROM (
  SELECT
    "NAME"
  , "RA"
  , "DEC"
  , row_number() OVER (PARTITION BY "NAME" ORDER BY "NAME","RA","DEC") AS n
  FROM import_table
  WHERE "NAME" IN (
  SELECT "NAME"
  FROM import_table
  GROUP BY "NAME"
  HAVING count(*)>1
  )
  ORDER BY "NAME","RA","DEC"
) AS t
WHERE
  import_table."NAME"=t."NAME"
  and import_table."RA"=t."RA"
  and import_table."DEC"=t."DEC"
;


EOB

};


sub WriteInsertData{
  my $fits470 = shift ;
  my $fits540 = shift ;
  my $fits656 = shift ;
  
print {$output} <<EOB;

------ Insert data into DB

INSERT INTO runset VALUES 
  ( (SELECT max(runid) FROM photorun) , '$fits470' )
, ( (SELECT max(runid) FROM photorun) , '$fits540' )
, ( (SELECT max(runid) FROM photorun) , '$fits656' )
;

INSERT INTO photoobj (runId, frameId, runObjId, ra, dec, mag, e_mag, type, class, quality)
SELECT 
  (SELECT max(runid) FROM photorun)
, '$fits470' 
, "NAME" 
, "RA" 
, "DEC" 
, "MAG_STD_470" 
, "MAGERR_STD_470" 
, 'BST'
, "CLASS_470"
, "FLAGS_470"
FROM import_table
WHERE 
  "MAG_STD_470" IS NOT NULL 
;

INSERT INTO photoobj (runId, frameId, runObjId, ra, dec, mag, e_mag, type, class, quality)
SELECT 
  (SELECT max(runid) FROM photorun)
, '$fits470' 
, "NAME" 
, "RA" 
, "DEC" 
, "MAG_STD_470_PSF" 
, "MAGERR_STD_470_PSF" 
, 'PSF'
, "CLASS_470"
, "FLAGS_470"
FROM import_table
WHERE 
  "MAG_STD_470_PSF" IS NOT NULL 
;


INSERT INTO photoobj (runId, frameId, runObjId, ra, dec, mag, e_mag, type, class, quality)
SELECT 
  (SELECT max(runid) FROM photorun)
, '$fits540' 
, "NAME" 
, "RA" 
, "DEC" 
, "MAG_STD_540" 
, "MAGERR_STD_540" 
, 'BST'
, "CLASS_540"
, "FLAGS_540"
FROM import_table
WHERE 
  "MAG_STD_540" IS NOT NULL 
;

INSERT INTO photoobj (runId, frameId, runObjId, ra, dec, mag, e_mag, type, class, quality)
SELECT 
  (SELECT max(runid) FROM photorun)
, '$fits540' 
, "NAME" 
, "RA" 
, "DEC" 
, "MAG_STD_540_PSF" 
, "MAGERR_STD_540_PSF" 
, 'PSF'
, "CLASS_540"
, "FLAGS_540"
FROM import_table
WHERE 
  "MAG_STD_540_PSF" IS NOT NULL 
;


INSERT INTO photoobj (runId, frameId, runObjId, ra, dec, mag, e_mag, type, class, quality)
SELECT 
  (SELECT max(runid) FROM photorun)
, '$fits656' 
, "NAME" 
, "RA" 
, "DEC" 
, "MAG_STD_656" 
, "MAGERR_STD_656" 
, 'BST'
, "CLASS_656"
, "FLAGS_656"
FROM import_table
WHERE 
  "MAG_STD_656" IS NOT NULL 
;

INSERT INTO photoobj (runId, frameId, runObjId, ra, dec, mag, e_mag, type, class, quality)
SELECT 
  (SELECT max(runid) FROM photorun)
, '$fits656' 
, "NAME" 
, "RA" 
, "DEC" 
, "MAG_STD_656_PSF" 
, "MAGERR_STD_656_PSF" 
, 'PSF'
, "CLASS_656"
, "FLAGS_656"
FROM import_table
WHERE 
  "MAG_STD_656_PSF" IS NOT NULL 
;


EOB
};
