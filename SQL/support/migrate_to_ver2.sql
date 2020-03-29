-- This SQL script is intended to migrate from SAO 3BS database version 1 to version 2
-- It saves the previous version of tables in the tables with prefix "v1_",
-- cleans the tables and modify the structure of the "photoobj" table.  
BEGIN;


-- Make copies --
CREATE TABLE v1_frame    AS SELECT * FROM frame ;
CREATE TABLE v1_photoobj AS SELECT * FROM photoobj ;
CREATE TABLE v1_photorun AS SELECT * FROM photorun ;
CREATE TABLE v1_runset   AS SELECT * FROM runset ;

-- Delete old data ---
DELETE FROM photoobj ;
DELETE FROM runset ;
DELETE FROM frame ;
DELETE FROM photorun ;



-- Drop tables which need modification --
DROP VIEW photoinfo ;
DROP VIEW photoobjframe ;

DROP TABLE objcrossid ;
DROP TABLE photoobj ;



-- Create auxiliary tables --
CREATE TABLE objclass (
  class       Char PRIMARY KEY
, description VarChar NOT NULL
);

COMMENT ON TABLE objclass  IS 'SExtractor classification of the photometry' ;
COMMENT ON COLUMN objclass.class       IS 'SExtractor class' ;
COMMENT ON COLUMN objclass.description IS 'Description of the class' ;

GRANT SELECT ON objclass TO PUBLIC ;


INSERT INTO objclass(class,description) VALUES
  ('S','Star')
, ('E','Extended')
, ('U','Unknown')
;


CREATE TABLE magtype (
  type        Char(3) PRIMARY KEY
, description VarChar NOT NULL
);

COMMENT ON TABLE magtype  IS 'Magnitude types' ;
COMMENT ON COLUMN magtype.type        IS 'Magnitude type' ;
COMMENT ON COLUMN magtype.description IS 'Description of the type' ;

GRANT SELECT ON magtype TO PUBLIC ;


INSERT INTO magtype(type,description) VALUES
  ('PSF','PSF photometry')
, ('BST','SExtractor''s MAG_BEST aperture magnitude')
;



-- Create photoObj table
CREATE TABLE photoobj (
  photoid  Serial PRIMARY KEY
, runid    Integer NOT NULL REFERENCES photorun (runid) ON DELETE restrict ON UPDATE cascade
, frameid  VarChar NOT NULL REFERENCES frame (frameid) ON DELETE restrict ON UPDATE cascade
, runobjid VarChar NOT NULL
, ra       Double Precision NOT NULL
, dec      Double Precision NOT NULL
, mag      Real NOT NULL
, e_mag    Real NOT NULL
, type     Char(3) NOT NULL REFERENCES magtype(type) ON DELETE restrict ON UPDATE cascade
, class    Char NOT NULL REFERENCES objclass (class) ON DELETE restrict ON UPDATE cascade
, quality  SmallInt NOT NULL
, UNIQUE (runid,frameid,runobjid,type)
);

CREATE INDEX ON photoobj (runobjid) ;
CREATE INDEX ON photoobj (frameid) ;
CREATE INDEX ON photoobj (runid) ;
CREATE INDEX ON photoobj (runid,runobjid) ;
CREATE INDEX ON photoobj (ra,dec) ;
CREATE INDEX ON photoobj (ra) ;
CREATE INDEX ON photoobj (dec) ;
CREATE INDEX ON photoobj (type) ;

COMMENT ON TABLE photoobj IS 'Photometry catalog' ;
COMMENT ON COLUMN photoobj.photoid  IS 'Internal photometry catalog number (automatically generated)' ;
COMMENT ON COLUMN photoobj.runid    IS 'Internal run number (see photorun)' ;
COMMENT ON COLUMN photoobj.frameid  IS 'Frame file name (see frame)' ;
COMMENT ON COLUMN photoobj.runobjid IS 'The object id in the photometry run (from the photometry table)' ;
COMMENT ON COLUMN photoobj.ra       IS 'RA of the object (deg) (from the photometry table)' ;
COMMENT ON COLUMN photoobj.dec      IS 'Dec of the object (deg) (from the photometry table)' ;
COMMENT ON COLUMN photoobj.mag      IS 'Magnitude (from the photometry table)' ;
COMMENT ON COLUMN photoobj.e_mag    IS 'Magnitude error (from the photometry table)' ;
COMMENT ON COLUMN photoobj.type     IS 'Type of the photometry (BST|PSF) (from the photometry table)' ;
COMMENT ON COLUMN photoobj.class    IS 'Object classification (S|E|U) based on SPREAD_MODEL (from the photometry table)' ;
COMMENT ON COLUMN photoobj.quality  IS 'SExtractor quality flag of the photometry (from the photometry table)' ;

GRANT SELECT ON photoobj TO PUBLIC ;


-- Restore crossidentification table --
CREATE TABLE IF NOT EXISTS objcrossid (
  objid    Integer NOT NULL REFERENCES star (objid) ON DELETE restrict ON UPDATE cascade
, photoid  Integer NOT NULL UNIQUE REFERENCES photoobj (photoid) ON DELETE restrict ON UPDATE cascade
, PRIMARY KEY (objid,photoid)
);

CREATE INDEX ON objcrossid (objid) ;
CREATE INDEX ON objcrossid (photoid) ;

COMMENT ON TABLE objcrossid IS 'Crossidentification catalog' ;
COMMENT ON COLUMN objcrossid.objid    IS 'Internal catalog object number (see star)' ;
COMMENT ON COLUMN objcrossid.photoid  IS 'Internal photometric catalog object number (see photoobj)' ;

GRANT SELECT ON objcrossid TO PUBLIC ;


-- Add indexes --
CREATE INDEX ON frame (dateobs);
CREATE INDEX ON frame (band);
CREATE INDEX ON frame (mjd);
CREATE INDEX ON frame (ra);
CREATE INDEX ON frame (dec);

-- ROLLBACK ;
COMMIT;
