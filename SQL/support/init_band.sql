BEGIN;

INSERT INTO biblio ( bibcode, authors, title, year )
VALUES ( '2019SAOPol..1....0G' , 'Gabdeev, M; Makarov, D.; Fatkhullin, T; Zhelenkova, O.' , 'Data Base: SAO Polars DR1' , 2019 ) ;


INSERT INTO band (  band, cwl, e_cwl, fwhm, e_fwhm, description, bibcode )
VALUES 
  ( 'SED470' , 470 , 2 , 10 , 2 , 'TECHSPEC Hard Coated OD 4 10nm Bandpass Filter, CWL=470' , '2019SAOPol..1....0G' )
, ( 'SED540' , 540 , 2 , 10 , 2 , 'TECHSPEC Hard Coated OD 4 10nm Bandpass Filter, CWL=540' , '2019SAOPol..1....0G' )
, ( 'SED656' , 656 , 2 , 10 , 2 , 'TECHSPEC Hard Coated OD 4 10nm Bandpass Filter, CWL=656' , '2019SAOPol..1....0G' )
;

COMMIT ;
