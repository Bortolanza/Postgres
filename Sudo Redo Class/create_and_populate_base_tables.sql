CREATE OR REPLACE FUNCTION create_and_populate_base_tables(caminho_do_log TEXT
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

    /*INSERTS THE LOG AND JSON VALUES INTO THEIR RESPECTIVE TABLES*/
    EXECUTE format($$COPY logs(logs) FROM %s$$, quote_literal(caminho_do_log));
    EXECUTE format($$COPY jay FROM %s$$, quote_literal(caminho_do_json));

    /*PROCESSES THE JSON, SEPARETING THE TABLE NAME FROM TABLE VALUES*/
    SELECT key_value.KEY, key_value.value::jsonb
      INTO jay_rec
      FROM jay
      JOIN jsonb_each_text(j) AS key_value ON TRUE;
  
    /*CREATE TABLE BASED ON THE JSON INFORMATION*/
    EXECUTE format($$CREATE TABLE IF NOT EXISTS %s(id int, a int, b int)$$, quote_ident(jay_rec.KEY));
    EXECUTE format($$TRUNCATE %s$$, jay_rec.KEY);

    /*PROCESSES THE JSON, BUILDS EACH TUPLE*/
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

    /*INSERT VALUES*/
    EXECUTE format($$INSERT INTO %s VALUES %s$$, quote_ident(jay_rec.KEY), array_to_string(cmd, ','));
    RETURN jay_rec.KEY;
END;
$function$;
