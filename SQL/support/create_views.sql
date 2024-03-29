BEGIN;

--------------- DUMB view on star catalog ----------------
CREATE OR REPLACE VIEW starinfo AS 
SELECT
  s.objid
, p.design
, c.ra
, c.dec
FROM 
  star AS s
  LEFT JOIN star_principal AS p USING (objid)
  LEFT JOIN coord AS c USING (cooid)
;

COMMENT ON VIEW starinfo IS 'Main stars parameters' ;
COMMENT ON COLUMN starinfo.objid  IS 'Internal catalog object number (see star)' ;
COMMENT ON COLUMN starinfo.design IS 'Principal Designation (see designation)' ;
COMMENT ON COLUMN starinfo.ra     IS 'Principal Right Ascension at epoch J2000 (see coord)' ;
COMMENT ON COLUMN starinfo.dec    IS 'Principal Declination at epoch J2000 (see coord)' ;

GRANT SELECT ON starinfo TO PUBLIC ;



------------- Colors view ----------------
CREATE OR REPLACE VIEW photoObjFrame AS
SELECT
  p1.photoid  
, p1.runid    
, p1.frameid  
, p1.runobjid  
, p1.ra       
, p1.dec      
, p1.mag      
, p1.e_mag    
, p1.type
, p1.class
, p1.quality  
, f1.dateobs
, f1.band   
, f1.exptime
, f1.mjd    
FROM 
  photoobj AS p1
  LEFT JOIN frame AS f1 USING (frameid)
;

GRANT SELECT ON photoObjFrame TO PUBLIC ;




DROP VIEW IF EXISTS photoinfo ;

CREATE OR REPLACE VIEW photoinfo AS
SELECT
  runid
, runobjid
, coalesce( psf1.ra, psf2.ra, psf3.ra ) AS ra
, coalesce( psf1.dec, psf2.dec, psf3.dec ) AS dec

, 0::Real AS x
, 0::Real AS y

, psf1.frameid AS frameid1
, psf1.band    AS band1
, psf1.mag     AS mag1
, psf1.e_mag   AS e_mag1
, aper1.mag     AS mag1aper
, aper1.e_mag   AS e_mag1aper
, psf1.class   AS class1
, psf1.quality AS quality1

, psf2.frameid AS frameid2
, psf2.band    AS band2
, psf2.mag     AS mag2
, psf2.e_mag   AS e_mag2
, aper2.mag     AS mag2aper
, aper2.e_mag   AS e_mag2aper
, psf2.class   AS class2
, psf2.quality AS quality2

, psf3.frameid AS frameid3
, psf3.band    AS band3
, psf3.mag     AS mag3
, psf3.e_mag   AS e_mag3
, aper3.mag     AS mag3aper
, aper3.e_mag   AS e_mag3aper
, psf3.class   AS class3
, psf3.quality AS quality3

, psf1.mag-psf2.mag                   AS color12
, sqrt( psf1.e_mag^2 + psf2.e_mag^2 ) AS e_color12
, psf2.mag-psf3.mag                   AS color23
, sqrt( psf2.e_mag^2 + psf3.e_mag^2 ) AS e_color23
, psf1.mag-psf3.mag                   AS color13
, sqrt( psf1.e_mag^2 + psf3.e_mag^2 ) AS e_color13

, aper1.mag-aper2.mag                   AS color12aper
, sqrt( aper1.e_mag^2 + aper2.e_mag^2 ) AS e_color12aper
, aper2.mag-aper3.mag                   AS color23aper
, sqrt( aper2.e_mag^2 + aper3.e_mag^2 ) AS e_color23aper
, aper1.mag-aper3.mag                   AS color13aper
, sqrt( aper1.e_mag^2 + aper3.e_mag^2 ) AS e_color13aper

FROM
  (SELECT * FROM photoObjFrame WHERE band='SED470' and type='PSF') AS psf1
  FULL JOIN (SELECT * FROM photoObjFrame WHERE band='SED540' and type='PSF') AS psf2 USING (runid,runobjid)
  FULL JOIN (SELECT * FROM photoObjFrame WHERE band='SED656' and type='PSF') AS psf3 USING (runid,runobjid)
  FULL JOIN (SELECT * FROM photoObjFrame WHERE band='SED470' and type='BST') AS aper1 USING (runid,runobjid)
  FULL JOIN (SELECT * FROM photoObjFrame WHERE band='SED540' and type='BST') AS aper2 USING (runid,runobjid)
  FULL JOIN (SELECT * FROM photoObjFrame WHERE band='SED656' and type='BST') AS aper3 USING (runid,runobjid)
;


COMMENT ON VIEW photoinfo IS 'Star photometry' ;
COMMENT ON COLUMN photoinfo.runid     IS 'Internal run number (see photorun)' ;
COMMENT ON COLUMN photoinfo.runobjid  IS 'The object number in the photometry run (see photoobj)' ;
COMMENT ON COLUMN photoinfo.ra        IS 'Right Ascension at epoch J2000 (see coord)' ;
COMMENT ON COLUMN photoinfo.dec       IS 'Declination at epoch J2000 (see coord)' ;

COMMENT ON COLUMN photoinfo.frameid1  IS 'Frame file name (see frame)' ;
COMMENT ON COLUMN photoinfo.band1     IS 'Filter used for observation (see band)' ;
COMMENT ON COLUMN photoinfo.mag1      IS 'PSF Magnitude (see photoobj)' ;
COMMENT ON COLUMN photoinfo.e_mag1    IS 'PSF Magnitude error (see photoobj)' ;
COMMENT ON COLUMN photoinfo.mag1aper   IS 'SExtractor''s MAG_BEST magnitude (see photoobj)' ;
COMMENT ON COLUMN photoinfo.e_mag1aper IS 'SExtractor''s MAG_BEST magnitude error (see photoobj)' ;
COMMENT ON COLUMN photoinfo.class1    IS 'Object classification using SPREAD_MODEL' ;
COMMENT ON COLUMN photoinfo.quality1  IS 'Quality flag' ;

COMMENT ON COLUMN photoinfo.frameid2  IS 'Frame file name (see frame)' ;
COMMENT ON COLUMN photoinfo.band2     IS 'Filter used for observation (see band)' ;
COMMENT ON COLUMN photoinfo.mag2      IS 'PSF Magnitude (see photoobj)' ;
COMMENT ON COLUMN photoinfo.e_mag2    IS 'PSF Magnitude error (see photoobj)' ;
COMMENT ON COLUMN photoinfo.mag2aper   IS 'SExtractor''s MAG_BEST magnitude (see photoobj)' ;
COMMENT ON COLUMN photoinfo.e_mag2aper IS 'SExtractor''s MAG_BEST magnitude error (see photoobj)' ;
COMMENT ON COLUMN photoinfo.class2    IS 'Object classification using SPREAD_MODEL' ;
COMMENT ON COLUMN photoinfo.quality2  IS 'Quality flag' ;

COMMENT ON COLUMN photoinfo.frameid3  IS 'Frame file name (see frame)' ;
COMMENT ON COLUMN photoinfo.band3     IS 'Filter used for observation (see band)' ;
COMMENT ON COLUMN photoinfo.mag3      IS 'PSF Magnitude (see photoobj)' ;
COMMENT ON COLUMN photoinfo.e_mag3    IS 'PSF Magnitude error (see photoobj)' ;
COMMENT ON COLUMN photoinfo.mag3aper   IS 'SExtractor''s MAG_BEST magnitude (see photoobj)' ;
COMMENT ON COLUMN photoinfo.e_mag3aper IS 'SExtractor''s MAG_BEST magnitude error (see photoobj)' ;
COMMENT ON COLUMN photoinfo.class3    IS 'Object classification using SPREAD_MODEL' ;
COMMENT ON COLUMN photoinfo.quality3  IS 'Quality flag' ;

COMMENT ON COLUMN photoinfo.color12   IS 'PSF Color index for 1 & 2 bands' ;
COMMENT ON COLUMN photoinfo.e_color12 IS 'PSF Color index error' ;
COMMENT ON COLUMN photoinfo.color23   IS 'PSF Color index for 2 & 3 bands' ;
COMMENT ON COLUMN photoinfo.e_color23 IS 'PSF Color index error' ;
COMMENT ON COLUMN photoinfo.color13   IS 'PSF Color index for 1 & 3 bands' ;
COMMENT ON COLUMN photoinfo.e_color13 IS 'PSF Color index error' ;

COMMENT ON COLUMN photoinfo.color12aper   IS 'Aperture color index for 1 & 2 bands' ;
COMMENT ON COLUMN photoinfo.e_color12aper IS 'Aperture color index error' ;
COMMENT ON COLUMN photoinfo.color23aper   IS 'Aperture color index for 2 & 3 bands' ;
COMMENT ON COLUMN photoinfo.e_color23aper IS 'Aperture color index error' ;
COMMENT ON COLUMN photoinfo.color13aper   IS 'Aperture color index for 1 & 3 bands' ;
COMMENT ON COLUMN photoinfo.e_color13aper IS 'Aperture color index error' ;


GRANT SELECT ON photoinfo TO PUBLIC ;


COMMIT;
