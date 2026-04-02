LIBNAME Data "/home/u64203762/BUT2/Reporting";

%let mv_del15 = 0.85;
%let mv_minima = 0.9;
%let mv_visites = 0.85;
%let mv_telagt = 0.9;

/* Déclaration des macro variables à partir de la date max de Data.gcaccpmm */
proc sql;
    create table work.parametres as
    select
        max(DDREFENR) as datemax format date9.,
        month(max(DDREFENR)) as mv_mois_m0,
        month(max(DDREFENR)-1) as mv_mois_mm1,
        year(max(DDREFENR)) as mv_annee_m0,
        year(max(DDREFENR))-2 as mv_annee_am2
        year(max(DDREFENR)-1)as mv_annee_compare
    from Data.gcaccpmm;
quit;

/* Création des macro variables */
data _null_ ;
    set work.parametres;
    call symput ('mv_mois_m0',put(mv_mois_m0,best.));
    call symput ('mv_mois_mm1',put(mv_mois_mm1,best.));
    call symput ('mv_annee_m0',put(mv_annee_m0,best.));
    call symput ('mv_annee_am2',put(mv_annee_am2,best.));
    call symput ('mv_annee_compare',put(mv_annee_compare,best.));
run;

/* récupération des données utiles pour le tableau de bord (filtrées) */
DATA gcsdpmm (DROP= TYPEORG);
    SET Data.gcsdpmm (KEEP=NUMORG DDREFENR TYPEORG NCOUA NCOUAS NPIEAT NPIPSO9T NPIPSO1T
                      NPIRP15T NPIRP16T NPIRA15T NPIRA16T
                      WHERE = (year(DDREFENR) >= &mv_annee_am2. and typeorg in ("CAF","NAT")));
RUN;


DATA gcaccpmm (DROP= TYPEORG);
    SET Data.gcaccpmm(KEEP=NUMORG DDREFENR TYPEORG NBVISTOT NBVIM20T
                      WHERE = (year(DDREFENR) >= &mv_annee_am2. and typeorg in ("CAF","NAT")));
RUN;


DATA gcacctmm (DROP= TYPEORG);
    SET Data.gcacctmm(KEEP=NUMORG DDREFENR TYPEORG TELABO TELABOS TELTRAGT TELTRSVT TELABOT TELTRAG TELTRAGS TELABAG TELABAGS
                      WHERE = (year(DDREFENR) >= &mv_annee_am2. and typeorg in ("CAF","NAT")));
RUN;
 
/* fusion des tables - Tri nécessaire pour le MERGE */
proc sort data = gcaccpmm; by NUMORG DDREFENR; run;
proc sort data = gcacctmm; by NUMORG DDREFENR; run;
proc sort data = gcsdpmm; by NUMORG DDREFENR; run;

DATA donnees;
    MERGE gcacctmm (in=a) gcsdpmm (in=b) gcaccpmm (in=c) ;
    BY NUMORG DDREFENR;
    if a and b and c;
RUN;


/* indicateurs mensuels (M0) - Correction des noms de variables et utilisation des macros */
PROC SQL;
    CREATE table work.indicateurs_mm as
    SELECT numorg, year(ddrefenr) as annee , month(ddrefenr) as mois,

    ncoua + ncouas as nbcourriers_mm label= "Nombre de courriers",
    NPIEAT as nbpieces_mm label= "Nombre de pièces",
    NBVISTOT as nbvis_mm label= "Nombre de visites",
    TELABO + TELABOS as nbappabo_mm label= "Nombre d'appels aboutis",
    (TELTRAGT + TELTRSVT) / TELABOT as txapptra_mm label= "Taux appels traités",
    (TELTRAG + TELTRAGS) / (TELABAG + TELABAGS) as txapptragt_mm label = "Taux appels traités agents",
    NPIPSO9T / (NPIPSO9T + NPIPSO1T ) as minima_mm label= "minima sociaux",
    (NPIRP15T + NPIRA15T) / (NPIRP15T + NPIRA15T + NPIRP16T + NPIRA16T) as del15_mm label= "Délais 15 min" ,
    NBVIM20T / NBVISTOT as VIS20_mm label= "Visites en 20 min" /* Correction: NBVIM20T */
   
    FROM donnees
 order by numorg, annee, mois   ;
quit;


/* Transposer indicateurs mensuels */

proc sort data= work.indicateurs_mm ; by numorg annee; run;
PROC transpose DATA = work.indicateurs_mm out= work.transpo_mm(drop = _label_);
    by numorg annee;
    id mois;
run;


/* indicateurs cumulés (CC) - Calcul du cumul jusqu'à M0 */
PROC SQL;
    CREATE table work.indicateurs_cc as
    SELECT numorg, year(ddrefenr) as annee,
   
    sum(ncoua + ncouas) AS nbcourriers_cc LABEL = "Nombre de courriers",
    sum(NPIEAT) AS nbpieces_cc LABEL = "Nombre de pièces",
    sum(NBVISTOT) AS nbvis_cc LABEL = "Nombre de visites",
    sum(TELABO + TELABOS) AS nbappabo_cc LABEL = "Nombre d'appels aboutis",
    sum(TELTRAGT + TELTRSVT) / sum(TELABOT) AS txapptra_cc LABEL = "Taux appels traités",
    sum(TELTRAG + TELTRAGS) / sum(TELABAG + TELABAGS) AS txapptragt_cc LABEL = "Taux appels traités agents",
    sum(NPIPSO9T) / sum(NPIPSO9T + NPIPSO1T) AS minima_cc LABEL = "Minima sociaux",
    sum(NPIRP15T + NPIRA15T) / sum(NPIRP15T + NPIRA15T + NPIRP16T + NPIRA16T) AS del15_cc LABEL = "Délais 15 min",
    sum(NBVIM20T) / sum(NBVISTOT) AS VIS20_cc LABEL = "Visites en 20 min"

    FROM donnees
    WHERE month(ddrefenr) <= &mv_mois_m0.
    GROUP BY numorg, year(ddrefenr)
    ;
quit;

proc sort data = work.indicateurs_cc; by numorg annee; run;

/* Transposer indicateurs cumulés - Correction de la table source */
proc transpose data = work.indicateurs_cc out = work.transpo_cc (drop = _label_);
    by numorg annee;
run;


/* Concaténation de deux tables (mensuels et cumulés) */
data tdb_fin;
    set work.transpo_mm work.transpo_cc;
run;

/* Tri final pour l'export */
proc sort data = tdb_fin;
    by numorg _name_ annee ;
run;


/* Exportation des données - Correction de la syntaxe PROC EXPORT (DBMS=) */
proc export data = tdb_fin
    outfile= "/home/u64203768/sasuser.v94/s3/tdb1_ems.xlsx"
    DBMS = XLSX replace;
    SHEET = "Indicateurs";
run;"/home/u64203768/sasuser.v94/s3";

/* Déclaration des macro variables à partir de la date max de Data.gcaccpmm */
proc sql;
    create table work.parametres as
    select
        max(DDREFENR) as datemax format date9.,
        month(max(DDREFENR)) as mv_mois_m0,
        year(max(DDREFENR)) as mv_annee_m0,
        year(max(DDREFENR))-2 as mv_annee_am2
    from Data.gcaccpmm;
quit;

/* Création des macro variables */
data _null_ ;
    set work.parametres;
    call symput ('mv_mois_m0',put(mv_mois_m0,best.));
    call symput ('mv_annee_m0',put(mv_annee_m0,best.));
    call symput ('mv_annee_am2',put(mv_annee_am2,best.));
run;

/* récupération des données utiles pour le tableau de bord (filtrées) */
DATA gcsdpmm (DROP= TYPEORG);
    SET Data.gcsdpmm (KEEP=NUMORG DDREFENR TYPEORG NCOUA NCOUAS NPIEAT NPIPSO9T NPIPSO1T
                      NPIRP15T NPIRP16T NPIRA15T NPIRA16T
                      WHERE = (year(DDREFENR) >= &mv_annee_am2. and typeorg in ("CAF","NAT")));
RUN;


DATA gcaccpmm (DROP= TYPEORG);
    SET Data.gcaccpmm(KEEP=NUMORG DDREFENR TYPEORG NBVISTOT NBVIM20T
                      WHERE = (year(DDREFENR) >= &mv_annee_am2. and typeorg in ("CAF","NAT")));
RUN;


DATA gcacctmm (DROP= TYPEORG);
    SET Data.gcacctmm(KEEP=NUMORG DDREFENR TYPEORG TELABO TELABOS TELTRAGT TELTRSVT TELABOT TELTRAG TELTRAGS TELABAG TELABAGS
                      WHERE = (year(DDREFENR) >= &mv_annee_am2. and typeorg in ("CAF","NAT")));
RUN;
 
/* fusion des tables - Tri nécessaire pour le MERGE */
proc sort data = gcaccpmm; by NUMORG DDREFENR; run;
proc sort data = gcacctmm; by NUMORG DDREFENR; run;
proc sort data = gcsdpmm; by NUMORG DDREFENR; run;

DATA donnees;
    MERGE gcacctmm (in=a) gcsdpmm (in=b) gcaccpmm (in=c) ;
    BY NUMORG DDREFENR;
    if a and b and c;
RUN;


/* indicateurs mensuels (M0) - Correction des noms de variables et utilisation des macros */
PROC SQL;
    CREATE table work.indicateurs_mm as
    SELECT numorg, year(ddrefenr) as annee , month(ddrefenr) as mois,

    ncoua + ncouas as nbcourriers_mm label= "Nombre de courriers",
    NPIEAT as nbpieces_mm label= "Nombre de pièces",
    NBVISTOT as nbvis_mm label= "Nombre de visites",
    TELABO + TELABOS as nbappabo_mm label= "Nombre d'appels aboutis",
    (TELTRAGT + TELTRSVT) / TELABOT as txapptra_mm label= "Taux appels traités",
    (TELTRAG + TELTRAGS) / (TELABAG + TELABAGS) as txapptragt_mm label = "Taux appels traités agents",
    NPIPSO9T / (NPIPSO9T + NPIPSO1T ) as minima_mm label= "minima sociaux",
    (NPIRP15T + NPIRA15T) / (NPIRP15T + NPIRA15T + NPIRP16T + NPIRA16T) as del15_mm label= "Délais 15 min" ,
    NBVIM20T / NBVISTOT as VIS20_mm label= "Visites en 20 min" /* Correction: NBVIM20T */
   
    FROM donnees
    ;
quit;


/* Transposer indicateurs mensuels */
PROC transpose DATA = work.indicateurs_mm out= work.transpo_mm(drop = _label_);
    by numorg annee;
    id mois;
run;


/* indicateurs cumulés (CC) - Calcul du cumul jusqu'à M0 */
PROC SQL;
    CREATE table work.indicateurs_cc as
    SELECT numorg, year(ddrefenr) as annee,
   
    sum(ncoua + ncouas) AS nbcourriers_cc LABEL = "Nombre de courriers",
    sum(NPIEAT) AS nbpieces_cc LABEL = "Nombre de pièces",
    sum(NBVISTOT) AS nbvis_cc LABEL = "Nombre de visites",
    sum(TELABO + TELABOS) AS nbappabo_cc LABEL = "Nombre d'appels aboutis",
    sum(TELTRAGT + TELTRSVT) / sum(TELABOT) AS txapptra_cc LABEL = "Taux appels traités",
    sum(TELTRAG + TELTRAGS) / sum(TELABAG + TELABAGS) AS txapptragt_cc LABEL = "Taux appels traités agents",
    sum(NPIPSO9T) / sum(NPIPSO9T + NPIPSO1T) AS minima_cc LABEL = "Minima sociaux",
    sum(NPIRP15T + NPIRA15T) / sum(NPIRP15T + NPIRA15T + NPIRP16T + NPIRA16T) AS del15_cc LABEL = "Délais 15 min",
    sum(NBVIM20T) / sum(NBVISTOT) AS VIS20_cc LABEL = "Visites en 20 min"

    FROM donnees
    WHERE month(ddrefenr) <= &mv_mois_m0.
    GROUP BY numorg, year(ddrefenr)
    ;
quit;

proc sort data = work.indicateurs_cc; by numorg annee; run;

/* Transposer indicateurs cumulés - Correction de la table source */
proc transpose data = work.indicateurs_cc out = work.transpo_cc (drop = _label_);
    by numorg annee;
run;


/* Concaténation de deux tables (mensuels et cumulés) */
data tdb_fin;
    set work.transpo_mm work.transpo_cc;
run;

/* Tri final pour l'export */
proc sort data = tdb_fin;
    by numorg _name_ annee ;
run;


/* Exportation des données - Correction de la syntaxe PROC EXPORT (DBMS=) */
proc export data = tdb_fin
    outfile= "/home/u64203762/BUT2/Reporting/tdb1_ems.xlsx"
    DBMS = XLSX replace;
    SHEET = "Indicateurs";
run;


/*********************** fin du programme pour le premier tdb **************************/




/******************** debut du programme pour le second tdb ****************************/

/* selection des indicateurs cumulés*/

data cumul (drop=annee);
set indicateurs_cc (keep= numorg annee del15_cc minima_cc VIS20_cc txapptragt_cc 
where=(annee = &mv_annee_m0.));
run;

/* selection des indicateurs du mois en cours */


data mois_m0 (drop=annee mois);
set indicateurs_mm(keep= numorg annee del15_mm minima_mm VIS20_mm txapptragt_mm 
where=(annee = &mv_annee_m0. and mois = &mv_mois_m0.));
rename del15_mm =del15_m0;
rename minima_mm =minima_m0;
rename VIS20_mm =VIS20_m0;
rename txapptragt_mm= txapptragt_m0;
run;

/* selection des indicateurs du mois précédent */

data mois_mm1 (drop=annee mois);
set indicateurs_mm(keep= numorg annee del15_mm minima_mm VIS20_mm txapptragt_mm 
where=(annee = &mv_annee_compare. and mois = &mv_mois_mm1.));
rename del15_mm =del15_mm1;
rename minima_mm =minima_mm1;
rename VIS20_mm =VIS20_mm1;
rename txapptragt_mm= txapptragt_mm1;
run;

/*fusion des trois tables */
proc sort data = cumul; by numorg; run;
proc sort data = mois_mm0; by numorg; run;
proc sort data = mois_mm1; by numorg; run;




data alertes (keep = numorg
vide1
del15_cc minima_cc VIS20_cc txapptragt_cc
vide2
del15_m0 minima_m0 VIS20_m0 txapptragt_m0
vide3
del min vis tel ind)
;
retain numorg
vide1
del15_cc minima_cc VIS20_cc txapptragt_cc
vide2
del15_m0 minima_m0 VIS20_m0 txapptragt_m0
vide3
del min vis tel ind ;
merge cumul mois_mm0 mois_mm1;
by numorg;


/* cra©ation  des indices*/
/* delais*/
if del15_m0 >= &mv_del15. and del15_m0 >= del15_mm1 then del = 1;
if del15_m0 >= &mv_del15. and del15_m0 < del15_mm1 then del = 2;
if del15_m0 < &mv_del15. and del15_m0 >= del15_mm1 then del = 3;
if del15_m0 < &mv_del15. and del15_m0 < del15_mm1 then del = 4;

if minima_m0 >= &mv_minima. and minima_m0 >= minima_mm1 then min = 1;
if minima_m0 >= &mv_minima. and minima_m0 < minima_mm1 then min = 2;
if minima_m0 < &mv_minima. and minima_m0 >= minima_mm1 then min = 3;
if minima_m0 < &mv_minima. and minima_m0 < minima_mm1 then min = 4;

if VIS20_m0 >= &mv_visites. and VIS20_m0 >= VIS20_mm1 then vis = 1;
if VIS20_m0 >= &mv_visites. and VIS20_m0 < VIS20_mm1 then vis = 2;
if VIS20_m0 < &mv_visites. and VIS20_m0 >= VIS20_mm1 then vis = 3;
if VIS20_m0 < &mv_visites. and VIS20_m0 < VIS20_mm1 then vis = 4;

if txapptragt_m0 >= &mv_telagt. and txapptragt_m0 >= txapptragt_mm1 then tel = 1;
if txapptragt_m0 >= &mv_telagt. and txapptragt_m0 < txapptragt_mm1 then tel = 2;
if txapptragt_m0 < &mv_telagt. and txapptragt_m0 >= txapptragt_mm1 then tel = 3;
if txapptragt_m0 < &mv_telagt. and txapptragt_m0 < txapptragt_mm1 then tel = 4;


vide1 = "";
vide2="";
vide3="";

ind = (del15_cc +minima_cc + VIS20_cc + txapptragt_cc) / 4;
run;

proc sort data= alertes; by ind; run;

proc export data=alertes
outfile= "/home/u64203762/BUT2/Reporting/tdb1_ems_alerte.xlsx"
dbms=xlsx replace;
run;






















