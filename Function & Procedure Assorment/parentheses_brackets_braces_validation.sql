CREATE OR REPLACE FUNCTION parentheses_brackets_braces_validation(string_array TEXT[])
RETURNS TEXT[]
LANGUAGE plpgsql
AS $function$
DECLARE
    string_array_in _TEXT;
    string_array_stack TEXT;
    x TEXT;
    y INT;
    stack_depth INT = 0;
    string TEXT;
    valid bool;
BEGIN
    FOREACH x IN ARRAY string_array LOOP

        SELECT string_to_array(x,NULL)
          INTO string_array_in;

        VALID = TRUE;
        stack_depth = 0;
        string_array_stack = '{}';

        IF string_array_in[1] ~ '\)|\}|\]' THEN    
            stack_depth = 1;
        ELSE
            FOR y IN 1..(SELECT array_length(string_array_in, 1)) LOOP

                IF string_array_in[y] = ANY(string_to_array('(,[,{', ',')) THEN
                    string_array_stack = string_array_stack||string_array_in[y];
                    stack_depth = stack_depth +1;
                    CONTINUE;
                END IF; 

                IF (string_array_in[y]::TEXT = ')' AND RIGHT(string_array_stack,1) = '(')
                OR (string_array_in[y]::TEXT = '}' AND RIGHT(string_array_stack,1) = '{')  
                OR (string_array_in[y]::TEXT = ']' AND RIGHT(string_array_stack,1) = '[')
                THEN
                    string_array_stack = LEFT(string_array_stack, -1);    
                    stack_depth = stack_depth - 1;
                    CONTINUE;  
                END IF;   

                EXIT; 
            END LOOP;
        END IF;

        VALID = stack_depth = 0;
        string = concat_ws(',', string, quote_literal(VALID));

    END LOOP;

    RETURN (SELECT string_to_array(string,','));
END; 
$function$;