CREATE OR REPLACE FUNCTION time_converter(hour_string TEXT)
RETURNS TIME
LANGUAGE plpgsql
AS $function$
DECLARE 
    v_hora _TEXT;
    hora TEXT;
BEGIN
    SELECT regexp_split_to_array(hour_string, ':', '')
      INTO v_hora;

    IF right(v_hora[3], 2) = 'PM' AND v_hora[1] != '00' THEN
        v_hora[1] = (SELECT ((v_hora[1])::int+12)::TEXT); 
    ELSEIF right(v_hora[3], 2) = 'AM' AND v_hora[1] = '12' THEN
        v_hora[1] = '00';
    END IF;

    RETURN (concat_ws(':', v_hora[1],v_hora[2], (SELECT left(v_hora[3], 2))))::TIME;   

END;
$function$;