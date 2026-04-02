
%macro SAE2025(Chemin= , 
			NomFichier= ,
			Onglet = ,
			ParametreSemaine= ,
			Perimetre= ,
			Frequence = );
			
/*Bornes temporelles*/
 data _bornes;
        format DateDebut DateFin ddmmyy10.;
        DateDebut = intnx('week', date(), &ParametreSemaine., 'Begin')+1; 
        DateFin= intnx('week', date(), 0, 'Begin');
        call symputx('DateDebut', DateDebut);
        call symputx('DateFin', DateFin);
    run;

/* Import du fichier excel de pilotage*/
  
PROC IMPORT DATAFILE = "&Chemin.\&NomFichier..xlsx"
               OUT = Pilotage(WHERE = (UPCASE('Critere_retour_initial'n) NE 'STOP' 
                                    AND (%DO i = 1 %TO %SYSFUNC(COUNTW(&Frequence., %STR( ))) ;
                                            UPCASE(frequence) = "%UPCASE(%SCAN(&Frequence., &i., %STR( )))"
											%IF &i. < %SYSFUNC(COUNTW(&Frequence., %STR( ))) %THEN OR ;
										 %END ;)
                                    AND (%DO i = 1 %TO %SYSFUNC(COUNTW(&Perimetre., %STR( ))) ;
                                           UPCASE(perimetre) = "%UPCASE(%SCAN(&Perimetre., &i., %STR( )))"
                                           %IF &i. < %SYSFUNC(COUNTW(&Perimetre., %STR( ))) %THEN OR ;
										%END ; )))
			   DBMS = XLSX REPLACE ;
			   SHEET = "&Onglet." ;
   RUN ;


/* Filtrage de la nouvelle table*/
data SAE_25;
set Pilotage;
run;	

data _null_;
    set SAE_25 end=fin;
    call symputx(cats('Fichier', _n_), strip("Fichier"n));
    call symputx(cats('NomPrgmSAS', _n_), strip("NomPrgmSAS"n));
    call symputx(cats('Repertoire', _n_), strip("Repertoire"n));
    call symputx(cats('Cible', _n_), strip("Cible"n));
    if fin then call symputx('NbLignes', _n_);
run;
    
/*Boucle pour acceder aux programmes*/


%do i=1 %to &NbLignes.;
%include "&&Repertoire&i..\&&Fichier&i...sas";
%&&NomPrgmSAS&i;
    %end;
    
%mend SAE2025;
%SAE2025(
    Chemin =Z:\BUT2\S3\SAS\SAE,
    NomFichier = Tableau_Pilotage,
    Onglet =Feuil1,
    ParametreSemaine = -1,
    Perimetre = EDD,
    Frequence = Hebdo);

