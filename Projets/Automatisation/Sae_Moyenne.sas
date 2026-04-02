/*Moyenne des âges */
libname Data "Z:\BUT2\S3\SAS\SAE";
data donnees_age;
    set Data.donnees;
	If not missing (DT_NAISSANCE) then do;
	Age = floor(yrdif(datepart(DT_NAISSANCE),ifn(missing(DT_DECES), today(), datepart(DT_DECES)),'AGE'));
   end;
run;


/*Moyenne des ages avec macro periode */

%macro Moyenne(nbsemaine= , Repertoire= ,Cible= );
    proc means data=donnees_age mean maxdec=2;
        where date_survenance between &DateDebut. and &DateFin.;
        var AGE;
        output out=Res_Periode (drop=_type_ _freq_) 
               mean=moyenne;
    run;
    
    /* Export du résultat dans Excel */
    proc export data=Res_Periode
        outfile="&&Repertoire&i..\&&Cible&i...xlsx"
        dbms=xlsx replace;
    run;
%mend Moyenne;

