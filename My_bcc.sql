DECLARE

ID_BCC_COURANT NUMBER :=  3 ;
NBR_HAB_PAR_DEPUTE NUMBER := 90;
Seuil INTEGER;
N INTEGER ;
S INTEGER ; 
SV INTEGER;
SR INTEGER;
QE INTEGER;
S_HAB INTEGER ; 
v_nbr_vote INTEGER;
SA INTEGER ;
--- Curseur pour la phase d elimination
Cursor C_ID_LC is select ID_LC from LISTE_CONDIDATE where ID_BCC = ID_BCC_COURANT ;

--- Curseur pour la phase d affectation des députés ( Suffrage attribué)
Cursor C_SA is select ID_LC , NBR_VOTES from LISTE_CONDIDATE where ID_BCC = ID_BCC_COURANT AND NBR_DEPUTE_LC = 0 ;

--- Cursor pour parcourir tous les candidat qu ils ont des reste et qu il ya encore de député
Cursor C_RESTE  is select ID_LC , RESTE_LC from LISTE_CONDIDATE where NBR_DEPUTE_LC IS NOT NULL AND ID_BCC = ID_BCC_COURANT ORDER BY RESTE_LC DESC ;
 
 enreg C_RESTE%ROWTYPE;


BEGIN

------------------------  ELIMINATION  ------------------------

----------------  CALCUL  SV ( LA SOMME DES VOTES VALABLES )

select SUM(NBR_VOTES_VALABLES)
    INTO SV
  FROM RESULTAT_LISTE_PAR_BV
   where ID_PV IN (   select ID_PV
                       from PV 
                        where ID_BV IN 
                        (   select ID_BV 
                            from BV 
                             where ID_COMN IN ( 
                                            select ID_COMN from COMMUNE 
                                            where ID_BCC = ID_BCC_COURANT
                                          )
                        )
                  );
                  
          

Seuil := 0.06 * SV ;

DBMS_OUTPUT.PUT_LINE('Suffrage Valable AVANT ELIMINATION : '||SV);
DBMS_OUTPUT.PUT_LINE('Seuil '||Seuil);



--------------  DESIGNER LE NOMBRE DE VOTE POUR CHAQUE CANDIDAT ET ELIMINER QLQ UNS
 
for V_ID IN C_ID_LC loop

 -- Selection la somme des votes pour chaque Liste candidate
  select SUM(NBR_VOTES_VALABLES) 
   INTO v_nbr_vote
    from RESULTAT_LISTE_PAR_BV
    where ID_LC = V_ID.ID_LC;
    
 ----------- update et faire nombre de vote pour chaque candidat,
    update LISTE_CONDIDATE 
     set NBR_VOTES = v_nbr_vote
      where ID_LC = V_ID.ID_LC;
      
 --0 pour les gens qui ne sont pas eliminé
 IF ( v_nbr_vote >= Seuil ) THEN
  update LISTE_CONDIDATE 
    set NBR_DEPUTE_LC = 0  
     where ID_LC = V_ID.ID_LC;
  END IF;

  COMMIT;
  
end loop;
  
----------------------------------- CALCUL QE ----------------------------------------

--------  CALCUL  S ( LA SOMME DES VOTES VALABLES POUR LES CANDIDAT QUI NE SONT PAS ELIMINE)

select SUM(NBR_VOTES)
    INTO S
     FROM  LISTE_CONDIDATE
      where ID_BCC =  ID_BCC_COURANT
       AND NBR_DEPUTE_LC IS NOT NULL ;
                
  DBMS_OUTPUT.PUT_LINE('Suffrage Valable Apré ELIMINATION : '||S);


---    LA SOMME DES HABITANTS D UN BCC

select SUM(C.NBR_HABITANTS_COMN)
    INTO S_HAB
  FROM COMMUNE C 
   where ID_BCC = ID_BCC_COURANT;
   
DBMS_OUTPUT.PUT_LINE('SOMME DES HABITANTS '||S_HAB);


---- N le nombre de député par BCC
N := S_HAB / NBR_HAB_PAR_DEPUTE ;

IF ( N > 5 ) THEN
 N := 5;
END IF;

DBMS_OUTPUT.PUT_LINE('Le nombre de Député '||N);

-- Sufrrage global
SR := N ;


QE := S / N ; 

DBMS_OUTPUT.PUT_LINE('QUOTIENT ELECTORAL Q= '||QE);



---------------------------------------------  AFFECTATION LE NOMBRE DE DEPUTE POUR CHAQUE CANDIDAT       ---------------------------------------------
            
for V_ID IN C_SA loop

SA := FLOOR( V_ID.NBR_VOTES / QE ) ;

----- ATTRIBUTION DES DEPUTE POUR CHAQUE CANDIDAT
IF ( SA > 0 ) then
 update LISTE_CONDIDATE 
    set NBR_DEPUTE_LC = SA 
     where ID_LC = V_ID.ID_LC;
     
  DBMS_OUTPUT.PUT_LINE('ID_LC =  '||V_ID.ID_LC||' NOMBRE DEPUTE ='||SA);
END IF;
COMMIT;

SR := SR - SA ;

end loop;

  DBMS_OUTPUT.PUT_LINE(' NOMBRE DE DEPUTE RESTE ENCORE : '||SR);
----------------------------------------  LA PHASE DE RESTE  ----------------------------------------

---- POUR REMPLIR LE CHAMP RESTE QUI SERA Manipulé par la suite

update LISTE_CONDIDATE L
  set L.RESTE_LC = NBR_VOTES - ( NBR_DEPUTE_LC * QE )
   where NBR_DEPUTE_LC IS NOT NULL
    AND ID_BCC = ID_BCC_COURANT ;

--- TESTEZ S IL RESTE ENCORE DES SUFFRAGES APRES AVOIR OUVRI LE Curseur
  OPEN C_RESTE ;

  WHILE ( SR > 0 ) LOOP
  
  fetch C_RESTE INTO enreg ;

  if C_RESTE%found then
  --- Ajout 1 député pour le Candidat courant 
  update LISTE_CONDIDATE
   set NBR_DEPUTE_LC = NBR_DEPUTE_LC + 1
    where ID_LC = enreg.ID_LC ;
    
    DBMS_OUTPUT.PUT_LINE('-- OP RESTE  : ID_LC =  '||enreg.ID_LC);

    COMMIT;
  END IF;
    SR := SR - 1;
   
  END LOOP;

  CLOSE C_RESTE;



EXCEPTION
 when OTHERS then
  DBMS_OUTPUT.PUT(' EXCEPTION ');

END;
      




