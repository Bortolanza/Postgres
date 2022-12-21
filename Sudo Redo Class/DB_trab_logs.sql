CREATE OR REPLACE FUNCTION cria_trunca_e_popula_tabela(caminho_do_log TEXT
                                                     , caminho_do_json TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $function$
DECLARE x record;
        cmd TEXT[];
        jay_rec RECORD;
BEGIN
    
    CREATE TABLE IF NOT EXISTS logs(id bigserial, logs TEXT);
    CREATE TABLE IF NOT EXISTS jay(j jsonb);
    TRUNCATE logs;
    TRUNCATE jay;

    /*INSERE VALORES DOS LOGS E DO JSON NAS TABELAS DEVIDAS*/
    EXECUTE format($$COPY logs(logs) FROM %s$$, quote_literal(caminho_do_log));
    EXECUTE format($$COPY jay FROM %s$$, quote_literal(caminho_do_json));

    /*PROCESSOA JSON, SEPARA NOME DA TABELA E VALORES DAS COLUNAS*/
    SELECT key_value.KEY, key_value.value::jsonb
      INTO jay_rec
      FROM jay
      JOIN jsonb_each_text(j) AS key_value ON TRUE;
  
    /*CRIA TABELA DE ACORDO COM NOME INFORMADO NO JSON*/
    EXECUTE format($$CREATE TABLE IF NOT EXISTS %s(id int, a int, b int)$$, quote_ident(jay_rec.KEY));
    EXECUTE format($$TRUNCATE %s$$, jay_rec.KEY);

    /*PROCESSA JSON, PARA RESGATAR VALORES DE CADA LINHA*/
    FOR x IN
        WITH cte1 AS (
            SELECT jsonb_array_elements(a::jsonb)::int a
                 , jsonb_array_elements(b::jsonb)::int b
              FROM jsonb_to_record(jay_rec.value) AS foo(a TEXT, b TEXT)
        )SELECT ROW_NUMBER() OVER() id
              , cte1.*
           FROM cte1         
    LOOP
        cmd[x.id] = format($$(%s, %s, %s)$$, x.id, x.a, x.b);
    END LOOP;

    /*INSERE VALORES*/
    EXECUTE format($$INSERT INTO %s VALUES %s$$, quote_ident(jay_rec.KEY), array_to_string(cmd, ','));
    RETURN jay_rec.KEY;
END;
$function$;






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
        /*VALIDA PARA SAIR DO LOOP QUANDO ENCONTROU TODOS OS POSSIVEIS ALVOS*/
        IF array_length(commits, 1) IS NULL
           AND array_length(starts, 1) IS NOT NULL
           AND array_length(ckpt, 1) IS NOT NULL
        THEN
            EXIT;
        END IF;
    
        /*LOCALIZA OPERACOES DE TRANSACOES*/
        IF regexp_like(rec.logs, '<T') = TRUE
        THEN
            aux_operacoes = ARRAY[string_to_array(trim(regexp_replace(rec.logs, '([|>|<|])', '', 'g')), ',')];
            /*VERIFICA SE OPERACOES SÃO DAS TRANSAÇÕES ALVO*/
            IF aux_operacoes[1][1] = ANY(commits) THEN
                operacoes = operacoes || aux_operacoes;
                CONTINUE;
            END IF;
            CONTINUE;
        END IF;
    
        /*LOCALIZA COMMITS QUE ESTÃO APÓS CKPT*/
        IF regexp_like(rec.logs, '<commit') = TRUE 
           AND array_length(ckpt, 1) IS NULL
        THEN
            commits = commits || trim(regexp_replace(rec.logs, '([^T.* |0-9])', '', 'g'));
            CONTINUE;
        END IF;
    
    
        /*LOCALIZA INICIO DE UMA TRANSAÇÃO*/
        IF regexp_like(rec.logs, '<start') = TRUE
        THEN
            aux_start = trim(regexp_replace(rec.logs, '([|>|<|\)|\(]|(start))', '', 'g'));
            /*VERIFICA SE É INICIO DE UMA DAS TRANSAÇÕES ALVO*/
            IF aux_start = ANY(commits) THEN
                commits = array_remove(commits, aux_start);
                starts = starts || aux_start;
                CONTINUE;
            END IF;
            CONTINUE;
        END IF;
    
    
        /*LOCALIZA CKPT*/
        IF regexp_like(rec.logs, '<CKPT') = TRUE
           AND array_length(ckpt, 1) IS NULL
        THEN
            ckpt = string_to_array(trim(regexp_replace('<CKPT (T3,T4,T5)>', '([|>|<|\)|\(]|(CKPT))', '', 'g')), ',');
            CONTINUE;
        END IF;
    
    END LOOP;

    /*PARA CADA OPERAÇÃO DAS TRANSAÇÕES PERTINENETES*/
    FOR i IN reverse array_length(operacoes, 1)..1
    LOOP
        EXECUTE format($$SELECT %s FROM %s WHERE id = %s$$, operacoes[1][3], quote_ident(nome_tabela), operacoes[i][2])
           INTO value;
       /*VERIFICA SE VALOR NA TABELA JÁ É O MESMO, SE SIM, NÃO EXECUTA*/
       IF value != (operacoes[i][5])::bigint THEN
            EXECUTE format($$UPDATE %s SET %s = %s WHERE id = %s$$, quote_ident(nome_tabela), operacoes[i][3], operacoes[i][5], operacoes[i][2]);
       END IF;
    END LOOP;

    EXECUTE format($$SELECT json_build_object(%s, json_build_object('ID', array_agg(foo.id ORDER BY id)
                                                                  , 'A' , array_agg(foo.a  ORDER BY id)
                                                                  , 'B' , array_agg(foo.b  ORDER BY id)
                                                                 )
                                           )
                     FROM %s AS foo$$, quote_literal(nome_tabela), quote_ident(nome_tabela))
    INTO tabela_apos_redo;

    RETURN query
    /*LISTA DAS TRANSAÇÕES DO REDO*/
    SELECT $$TRANSAÇÕES PARA REDO$$, starts::TEXT
     UNION ALL
    /*LISTA DAS OPERAÇÕES DO REDO*/
    SELECT $$OPERACOES QUE SERAO AVALIADAS$$, operacoes::TEXT
     UNION ALL
    /*ESTADO FINAL DA TABELA*/
    SELECT $$TABELA APOS OPERACOES$$, tabela_apos_redo;

END;
$function$;


SELECT redo.tag
     , redo.content
  FROM cria_trunca_e_popula_tabela('/home/shared/log', '/home/shared/jayzao.json') AS cria_trunca_e_popula_tabela(tabela)
  JOIN LATERAL redo(cria_trunca_e_popula_tabela.tabela) ON TRUE;
  
  