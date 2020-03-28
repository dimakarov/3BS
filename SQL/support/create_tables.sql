BEGIN;


-------------- Bibliography ---------------------
CREATE TABLE IF NOT EXISTS biblio (
  bibcode Char(19) PRIMARY KEY
, authors VarChar NOT NULL
, title   VarChar NOT NULL
, year    SmallInt NOT NULL
, CHECK (year>1900)
);

COMMENT ON TABLE biblio IS 'Bibliography catalog' ;
COMMENT ON COLUMN biblio.bibcode IS 'ADS bibcode' ;
COMMENT ON COLUMN biblio.authors IS 'List of authors' ;
COMMENT ON COLUMN biblio.title   IS 'Title of the article' ;
COMMENT ON COLUMN biblio.year    IS 'Year of publication' ;

GRANT SELECT ON biblio TO PUBLIC ;



-------------- Star catalog ---------------------
CREATE TABLE IF NOT EXISTS star (
  objid  Serial PRIMARY KEY
) ;

COMMENT ON TABLE star IS 'Star catalog' ;
COMMENT ON COLUMN star.objid IS 'Internal catalog object number (automatically generated).' ;

GRANT SELECT ON star TO PUBLIC ;



CREATE TABLE IF NOT EXISTS designation (
  objid   Integer NOT NULL REFERENCES star (objid) ON DELETE restrict ON UPDATE cascade
, design  VarChar NOT NULL UNIQUE
, bibcode Char(19) NOT NULL REFERENCES biblio (bibcode) ON DELETE restrict ON UPDATE cascade
, PRIMARY KEY (objid,design)
) ;

COMMENT ON TABLE designation IS 'Designation catalog' ;
COMMENT ON COLUMN designation.objid   IS 'Internal catalog object number (see star)' ;
COMMENT ON COLUMN designation.design  IS 'Designation' ;
COMMENT ON COLUMN designation.bibcode IS 'ADS bibcode (see biblio)' ;

GRANT SELECT ON designation TO PUBLIC ;



CREATE TABLE IF NOT EXISTS coord (
  cooid   Serial PRIMARY KEY
, objid   Integer NOT NULL REFERENCES star (objid) ON DELETE restrict ON UPDATE cascade
, ra      Double Precision NOT NULL
, dec     Double Precision NOT NULL
, e_ra    Double Precision
, e_dec   Double Precision
, bibcode Char(19) NOT NULL REFERENCES biblio (bibcode) ON DELETE restrict ON UPDATE cascade
, CHECK (ra>=0 and ra<360 and dec>=-90 and dec<=90)
);
CREATE INDEX ON coord (objid,ra,dec) ;
CREATE INDEX ON coord (ra,dec) ;
CREATE INDEX ON coord (ra) ;
CREATE INDEX ON coord (dec) ;

COMMENT ON TABLE coord IS 'Coordinates catalog' ;
COMMENT ON COLUMN coord.cooid  IS 'Internal coordinate number (automatically generated)' ;
COMMENT ON COLUMN coord.objid  IS 'Internal catalog object number (see star)' ;
COMMENT ON COLUMN coord.ra     IS 'Right ascension at epoch J2000 (deg)' ;
COMMENT ON COLUMN coord.dec    IS 'Declination at epoch J2000 (deg)' ;
COMMENT ON COLUMN coord.e_ra   IS 'Error of the Right ascension at epoch J2000 (deg)' ;
COMMENT ON COLUMN coord.e_dec  IS 'Error of the Declination at epoch J2000 (deg)' ;

GRANT SELECT ON coord TO PUBLIC ;



CREATE TABLE IF NOT EXISTS star_principal (
  objid   Integer PRIMARY KEY REFERENCES star (objid) ON DELETE restrict ON UPDATE cascade
, design  VarChar NOT NULL UNIQUE
, cooid   Integer NOT NULL UNIQUE REFERENCES coord (cooid) ON DELETE restrict ON UPDATE cascade
, FOREIGN KEY (objid,design) REFERENCES designation (objid,design) ON DELETE restrict ON UPDATE cascade
);

COMMENT ON TABLE star_principal IS 'Main stars parameters' ;
COMMENT ON COLUMN star_principal.objid  IS 'Internal catalog object number (see star)' ;
COMMENT ON COLUMN star_principal.design IS 'Principal Designation (see designation)' ;
COMMENT ON COLUMN star_principal.cooid  IS 'Principal coordinate number (see coord)' ;

GRANT SELECT ON star_principal TO PUBLIC ;



-------------- Bandpass catalog -------------------
CREATE TABLE IF NOT EXISTS band (
  band        VarChar PRIMARY KEY
, cwl         Real NOT NULL
, e_cwl       Real
, fwhm        Real NOT NULL
, e_fwhm      Real
, description VarChar
, bibcode     Char(19) NOT NULL REFERENCES biblio (bibcode) ON DELETE restrict ON UPDATE cascade
);
CREATE INDEX ON band (cwl) ;

COMMENT ON TABLE band IS 'Bandpass catalog' ;
COMMENT ON COLUMN band.band    IS 'Bandpass name' ;
COMMENT ON COLUMN band.cwl     IS 'The central wavelength of the band (nm)' ;
COMMENT ON COLUMN band.fwhm    IS 'FWHM of the band (nm)' ;
COMMENT ON COLUMN band.description IS 'Band description' ;
COMMENT ON COLUMN band.bibcode IS 'ADS bibcode (see biblio)' ;

GRANT SELECT ON band TO PUBLIC ;


-------------- FITS catalog ---------------------
CREATE TABLE IF NOT EXISTS frame (
  frameid  VarChar PRIMARY KEY 
, dateobs  TimeStamp without time zone NOT NULL
, band     VarChar NOT NULL REFERENCES band (band) ON DELETE restrict ON UPDATE cascade
, exptime  Real NOT NULL
, mjd      Double Precision NOT NULL
, ra       Double Precision NOT NULL
, dec      Double Precision NOT NULL
, header   JSON
);

COMMENT ON TABLE frame IS 'FITS file catalog' ;
COMMENT ON COLUMN frame.frameid  IS 'Frame file name' ;
COMMENT ON COLUMN frame.dateobs  IS 'Start of the exposure in UTC' ;
COMMENT ON COLUMN frame.band     IS 'Filter used for observation (see band)' ;
COMMENT ON COLUMN frame.exptime  IS 'Exposure time (sec)' ;
COMMENT ON COLUMN frame.mjd      IS 'Date of observation in MJD (in UTC system)' ;
COMMENT ON COLUMN frame.ra       IS 'Approximate RA center of the CCD (deg)' ;
COMMENT ON COLUMN frame.dec      IS 'Approximate Dec center of this CCD (deg)' ;
COMMENT ON COLUMN frame.header   IS 'FITS header' ;

GRANT SELECT ON frame TO PUBLIC ;



-------------- PhotoObj catalog ---------------------
CREATE TABLE IF NOT EXISTS photorun (
  runid       Serial PRIMARY KEY
, description VarChar
);

COMMENT ON TABLE photorun IS 'Protometric run on frames' ;
COMMENT ON COLUMN photorun.runid        IS 'Internal run number (automatically generated)' ;
COMMENT ON COLUMN photorun.description  IS 'Description of the run' ;

GRANT SELECT ON photorun TO PUBLIC ;



CREATE TABLE IF NOT EXISTS runset (
  runid   Integer NOT NULL REFERENCES photorun (runid) ON DELETE restrict ON UPDATE cascade
, frameid VarChar NOT NULL REFERENCES frame (frameid) ON DELETE restrict ON UPDATE cascade
, PRIMARY KEY (runid,frameid)
) ;

COMMENT ON TABLE runset IS 'Set of frames in the run' ;
COMMENT ON COLUMN runset.runid   IS 'Internal run number (see photorun)' ;
COMMENT ON COLUMN runset.frameid  IS 'Frame file name (see frame)' ;

GRANT SELECT ON runset TO PUBLIC ;



CREATE TABLE IF NOT EXISTS photoobj (
  photoid  Serial PRIMARY KEY
, runid    Integer NOT NULL REFERENCES photorun (runid) ON DELETE restrict ON UPDATE cascade
, frameid  VarChar NOT NULL REFERENCES frame (frameid) ON DELETE restrict ON UPDATE cascade
, runobjid VarChar NOT NULL 
, x        Real NOT NULL
, y        Real NOT NULL
, ra       Double Precision NOT NULL
, dec      Double Precision NOT NULL
, mag      Real NOT NULL
, e_mag    Real NOT NULL
, quality  SmallInt NOT NULL
, FOREIGN KEY (runid,frameid) REFERENCES runset (runid,frameid) ON DELETE restrict ON UPDATE cascade
);
CREATE INDEX ON photoobj (runid,runobjid) ;
CREATE INDEX ON photoobj (runid,frameid,runobjid) ;
CREATE INDEX ON photoobj (ra,dec) ;
CREATE INDEX ON photoobj (ra) ;
CREATE INDEX ON photoobj (dec) ;
CREATE INDEX ON photoobj (x,y) ;
CREATE INDEX ON photoobj (x) ;
CREATE INDEX ON photoobj (y) ;

COMMENT ON TABLE photoobj IS 'Photometry catalog' ;
COMMENT ON COLUMN photoobj.photoid  IS 'Internal photometry catalog number (automatically generated)' ;
COMMENT ON COLUMN photoobj.runid    IS 'Internal run number (see photorun)' ;
COMMENT ON COLUMN photoobj.frameid  IS 'Frame file name (see frame)' ;
COMMENT ON COLUMN photoobj.runobjid IS 'The object id in the photometry run (from the photometry table)' ;
COMMENT ON COLUMN photoobj.x        IS 'X coordinate of the object in the frame (from the photometry table)' ;
COMMENT ON COLUMN photoobj.y        IS 'Y coordinate of the object in the frame (from the photometry table)' ;
COMMENT ON COLUMN photoobj.ra       IS 'RA of the object (deg) (from the photometry table)' ;
COMMENT ON COLUMN photoobj.dec      IS 'Dec of the object (deg) (from the photometry table)' ;
COMMENT ON COLUMN photoobj.dec      IS 'Dec of the object (deg) (from the photometry table)' ;
COMMENT ON COLUMN photoobj.mag      IS 'Magnitude (from the photometry table)' ;
COMMENT ON COLUMN photoobj.e_mag    IS 'Magnitude error (from the photometry table)' ;
COMMENT ON COLUMN photoobj.quality  IS 'Quality flag of the photometry (from the photometry table)' ;

GRANT SELECT ON photoobj TO PUBLIC ;



-------------- Objects crossidentification ---------------------
CREATE TABLE IF NOT EXISTS objcrossid (
  objid    Integer NOT NULL REFERENCES star (objid) ON DELETE restrict ON UPDATE cascade
, photoid  Integer NOT NULL UNIQUE REFERENCES photoobj (photoid) ON DELETE restrict ON UPDATE cascade
, PRIMARY KEY (objid,photoid)
);

COMMENT ON TABLE objcrossid IS 'Crossidentification catalog' ;
COMMENT ON COLUMN objcrossid.objid    IS 'Internal catalog object number (see star)' ;
COMMENT ON COLUMN objcrossid.photoid  IS 'Internal photometric catalog object number (see photoobj)' ;

GRANT SELECT ON objcrossid TO PUBLIC ;



COMMIT;
