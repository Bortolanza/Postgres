CREATE OR REPLACE FUNCTION redo(nome_tabela TEXT)
RETURNS TABLE  (tag TEXT, content TEXT)
LANGUAGE plpgsql
AS $function$
DECLARE ckpt TEXT[];
        commits TEXT[];
        starts TEXT[];
        operacoes TEXT[];
        aux_operacoes TEXT[];
        aux_start TEXT;
        value bigint;
        tabela_apos_redo TEXT;
        rec RECORD;
BEGIN

    FOR rec IN
             SELECT logs
               FROM logs
              ORDER BY id DESC
    LOOP
        /*EXITS LOOP WHEN ALL VALID TARGETS ARE FOUND*/
        IF array_length(commits, 1) IS NULL
           AND array_length(starts, 1) IS NOT NULL
           AND array_length(ckpt, 1) IS NOT NULL
        THEN
            EXIT;
        END IF;
    
        /*LOCATES ANY OPERATION*/
        IF regexp_like(rec.logs, '<T') = TRUE
        THEN
            aux_operacoes = ARRAY[string_to_array(trim(regexp_replace(rec.logs, '([|>|<|])', '', 'g')), ',')];
            /*CHECKS IF OPERATION IS FROM A VALID TRANSACTION*/
            IF aux_operacoes[1][1] = ANY(commits) THEN
                operacoes = operacoes || aux_operacoes;
                CONTINUE;
            END IF;
            CONTINUE;
        END IF;
    
        /*LOCATES VALID COMMITS*/
        IF regexp_like(rec.logs, '<commit') = TRUE 
           AND array_length(ckpt, 1) IS NULL
        THEN
            commits = commits || trim(regexp_replace(rec.logs, '([^T.* |0-9])', '', 'g'));
            CONTINUE;
        END IF;
    
    
        /*LOCATES TRANSACTION STARTS*/
        IF regexp_like(rec.logs, '<start') = TRUE
        THEN
            aux_start = trim(regexp_replace(rec.logs, '([|>|<|\)|\(]|(start))', '', 'g'));
            /*CHECKS IF THE START IS OF A VALID TRANSACTION*/
            IF aux_start = ANY(commits) THEN
                commits = array_remove(commits, aux_start);
                starts = starts || aux_start;
                CONTINUE;
            END IF;
            CONTINUE;
        END IF;
    
    
        /*LOCATES CKPT*/
        IF regexp_like(rec.logs, '<CKPT') = TRUE
           AND array_length(ckpt, 1) IS NULL
        THEN
            ckpt = string_to_array(trim(regexp_replace('<CKPT (T3,T4,T5)>', '([|>|<|\)|\(]|(CKPT))', '', 'g')), ',');
            CONTINUE;
        END IF;
    
    END LOOP;

    /*FOR EACH VALID OPERATION*/
    FOR i IN reverse array_length(operacoes, 1)..1
    LOOP
        EXECUTE format($$SELECT %s FROM %s WHERE id = %s$$, operacoes[1][3], quote_ident(nome_tabela), operacoes[i][2])
           INTO value;
       /*CHECKS THE TABLE VALUE, IF EQUAL, DOESN'T EXECUTE*/
       IF value != (operacoes[i][5])::bigint THEN
            EXECUTE format($$UPDATE %s SET %s = %s WHERE id = %s$$, quote_ident(nome_tabela), operacoes[i][3], operacoes[i][5], operacoes[i][2]);
       END IF;
    END LOOP;

    /*GETS TABLE FINAL STATE*/
    EXECUTE format($$SELECT json_build_object(%s, json_build_object('ID', array_agg(foo.id ORDER BY id)
                                                                  , 'A' , array_agg(foo.a  ORDER BY id)
                                                                  , 'B' , array_agg(foo.b  ORDER BY id)
                                                                 )
                                           )
                     FROM %s AS foo$$, quote_literal(nome_tabela), quote_ident(nome_tabela))
    INTO tabela_apos_redo;

    RETURN query
    /*LIST OF ALL REDO TRANSACTIONS*/
    SELECT $$TRANSAÇÕES PARA REDO$$, starts::TEXT
     UNION ALL
    /*LIST OF ALL REDO OPERATIONS*/
    SELECT $$OPERACOES QUE SERAO AVALIADAS$$, operacoes::TEXT
     UNION ALL
    /*TABLE FINAL STATE*/
    SELECT $$TABELA APOS OPERACOES$$, tabela_apos_redo;

END;
$function$;
