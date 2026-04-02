libname Data "Z:\BUT2\S3\SAS\SAE";
%macro Somme(nbsemaine= , Repertoire= ,Cible= );

    /* Calcul de la somme sur la période */
    proc means data=Data.donnees noprint sum maxdec=2;
        where date_survenance between &DateDebut and &DateFin;
        var MNT_RESTANT_A_SOLDER;
        output out=Res_Periode (drop=_type_ _freq_) 
               sum=Somme_MNT_RESTANT_A_SOLDER;
    run; 

    /* Export du résultat dans Excel */
    proc export data=Res_Periode
        OUTFILE="&&Repertoire&i..\&&Cible&i...xlsx"
        dbms=xlsx replace;
    run;

%mend Somme;



