CREATE OR REPLACE FUNCTION string_merge(p_string_1 TEXT, p_string_2 TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $function$
DECLARE 
    string_1 _TEXT;
    string_2 _TEXT;
    string_3 TEXT = '';
    sz_1 int;
    sz_2 int;
BEGIN
    SELECT length(p_string_1)
      INTO sz_1;

    SELECT length(p_string_2)  
      INTO sz_2;

    SELECT string_to_array(p_string_1, NULL) 
      INTO string_1;

    SELECT string_to_array(p_string_2, NULL)
      INTO string_2;

    FOR x IN 1..LEAST(sz_1, sz_2)-1 LOOP
        string_3 = string_3||string_1[x]||string_2[x];
    END LOOP;

    string_3 = string_3||array_to_string(string_1[LEAST(sz_1, sz_2)+1:sz_1],'','')||array_to_string(string_2[LEAST(sz_1, sz_2)+1:sz_2],'','');    

    RETURN string_3;    
END;
$function$;