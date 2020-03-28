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
, p1.x        
, p1.y        
, p1.ra       
, p1.dec      
, p1.mag      
, p1.e_mag    
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


CREATE OR REPLACE VIEW photoinfo AS
SELECT
  runid
, runobjid
, coalesce( p1.x, p2.x, p3.x ) AS x
, coalesce( p1.y, p2.y, p3.y ) AS y
, coalesce( p1.ra, p2.ra, p3.ra ) AS ra
, coalesce( p1.dec, p2.dec, p3.dec ) AS dec
, p1.frameid AS frameid1
, p2.frameid AS frameid2
, p3.frameid AS frameid3
, p1.band    AS band1
, p2.band    AS band2
, p3.band    AS band3
, p1.mag     AS mag1
, p1.e_mag   AS e_mag1
, p2.mag     AS mag2
, p2.e_mag   AS e_mag2
, p3.mag     AS mag3
, p3.e_mag   AS e_mag3
, p1.mag-p2.mag                   AS color12
, sqrt( p1.e_mag^2 + p2.e_mag^2 ) AS e_color12
, p2.mag-p3.mag                   AS color23
, sqrt( p2.e_mag^2 + p3.e_mag^2 ) AS e_color23
, p1.mag-p3.mag                   AS color13
, sqrt( p1.e_mag^2 + p3.e_mag^2 ) AS e_color13
, p1.quality AS quality1
, p2.quality AS quality2
, p3.quality AS quality3
FROM
  (SELECT * FROM photoObjFrame WHERE band='SED470') AS p1
  FULL JOIN (SELECT * FROM photoObjFrame WHERE band='SED540') AS p2 USING (runid,runobjid)
  FULL JOIN (SELECT * FROM photoObjFrame WHERE band='SED656') AS p3 USING (runid,runobjid)
;

COMMENT ON VIEW photoinfo IS 'Star photometry' ;
COMMENT ON COLUMN photoinfo.runid     IS 'Internal run number (see photorun)' ;
COMMENT ON COLUMN photoinfo.runobjid  IS 'The object number in the photometry run (see photoobj)' ;
COMMENT ON COLUMN photoinfo.x         IS 'X coordinate of the object in the frame (see photoobj)' ;
COMMENT ON COLUMN photoinfo.y         IS 'Y coordinate of the object in the frame (see photoobj)' ;
COMMENT ON COLUMN photoinfo.ra        IS 'Right Ascension at epoch J2000 (see coord)' ;
COMMENT ON COLUMN photoinfo.dec       IS 'Declination at epoch J2000 (see coord)' ;
COMMENT ON COLUMN photoinfo.dec       IS 'Declination at epoch J2000 (see coord)' ;
COMMENT ON COLUMN photoinfo.frameid1  IS 'Frame file name (see frame)' ;
COMMENT ON COLUMN photoinfo.frameid2  IS 'Frame file name (see frame)' ;
COMMENT ON COLUMN photoinfo.frameid3  IS 'Frame file name (see frame)' ;
COMMENT ON COLUMN photoinfo.band1     IS 'Filter used for observation (see band)' ;
COMMENT ON COLUMN photoinfo.band2     IS 'Filter used for observation (see band)' ;
COMMENT ON COLUMN photoinfo.band3     IS 'Filter used for observation (see band)' ;
COMMENT ON COLUMN photoinfo.mag1      IS 'Magnitude (see photoobj)' ;
COMMENT ON COLUMN photoinfo.e_mag1    IS 'Magnitude error (see photoobj)' ;
COMMENT ON COLUMN photoinfo.mag2      IS 'Magnitude (see photoobj)' ;
COMMENT ON COLUMN photoinfo.e_mag2    IS 'Magnitude error (see photoobj)' ;
COMMENT ON COLUMN photoinfo.mag3      IS 'Magnitude (see photoobj)' ;
COMMENT ON COLUMN photoinfo.e_mag3    IS 'Magnitude error (see photoobj)' ;
COMMENT ON COLUMN photoinfo.color12   IS 'Color index for 1 & 2 bands' ;
COMMENT ON COLUMN photoinfo.e_color12 IS 'Color index error' ;
COMMENT ON COLUMN photoinfo.color23   IS 'Color index for 2 & 3 bands' ;
COMMENT ON COLUMN photoinfo.e_color23 IS 'Color index error' ;
COMMENT ON COLUMN photoinfo.quality1  IS 'Quality flag' ;
COMMENT ON COLUMN photoinfo.quality2  IS 'Quality flag' ;
COMMENT ON COLUMN photoinfo.quality3  IS 'Quality flag' ;

GRANT SELECT ON photoinfo TO PUBLIC ;

COMMIT;
