
libname Data "Z:\BUT2\S3\SAS\SAE";

data donnees_montant;
    set Data.donnees;
run;



/*Nombre de montant nul ou non nuls */
%macro MontantNUL(nbsemaine=,Repertoire=, Cible=);

    proc sql;
    create table MONTANTNUL as
        select 
            count(case when MNT_RESTANT_A_SOLDER = 0 then 1 end) as Nb_Nuls,
            count(case when MNT_RESTANT_A_SOLDER ne 0 then 1 end) as Nb_NonNuls
        from Data.donnees
        where date_survenance between &DateDebut and &DateFin;
    quit;

PROC EXPORT DATA=MONTANTNUL
	outfile="&&Repertoire&i..\&&Cible&i...xlsx"
    DBMS=XLSX REPLACE;
RUN;

	
%mend MontantNUL;
