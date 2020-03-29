BEGIN;

DELETE FROM photoobj ;
ALTER SEQUENCE photoobj_photoid_seq RESTART ;

DELETE FROM star ;
ALTER SEQUENCE star_objid_seq RESTART ;

DELETE FROM star_principal ;

DELETE FROM runset ;

DELETE FROM photorun ;
ALTER SEQUENCE photorun_runid_seq RESTART ;

DELETE FROM objcrossid ;

DELETE FROM frame ;

DELETE FROM designation ;

DELETE FROM coord ;
ALTER SEQUENCE coord_cooid_seq RESTART ;


COMMIT ;









