CREATE OR REPLACE FUNCTION t_replace_icon()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
END;
$function$;
CREATE OPERATOR + (
    LEFTARG = point,
    RIGHTARG = point,
    FUNCTION = add_point
);
CREATE OR REPLACE FUNCTION add_point(p1 point, p2 point)
 RETURNS point
 LANGUAGE plpgsql
 AS $function$
 DECLARE
    p point;
BEGIN
    EXECUTE format($$SELECT ((%s),(%s))::point$$, p1[0]+p2[0], p1[1]+p2[1]);
    RETURN p;
END
 $function$;
CREATE OR REPLACE FUNCTION t_replace_icon()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    campo_value TEXT;
BEGIN
    SELECT CASE NEW.cell_value
              WHEN 'V' THEN '🌿'
              WHEN 'SH' THEN '🐍'
              WHEN 'F' THEN '🍒'
              WHEN 'SB' THEN 'SB'
           END 
    INTO campo_value;
    EXECUTE format($$UPDATE campo SET c_%s = '%s' WHERE row_numb = (%L)::int $$, NEW.coord[0], campo_value, NEW.coord[1]);
    RETURN NEW;
END 
$function$
CREATE OR REPLACE PROCEDURE cria_campo(p_tamanho bigint)
LANGUAGE plpgsql
AS $procedure$
DECLARE
        rec_tab record;
        col int;
        lin int;
        rec record;
        /*🐍, 🌿*/
BEGIN
    DROP TABLE IF EXISTS campo;
    DROP TABLE IF EXISTS game_data;
    DROP TABLE IF EXISTS campo_cell;
    IF p_tamanho NOT BETWEEN 5 AND 15 THEN                                  
        RAISE EXCEPTION 'Necessario informar tamanho entre 5 e 15';
    END IF;
    CREATE TABLE game_data(sz int,
                           total_point bigint,
                           grow_point bigint,
                           last_move TEXT);                                           -- CREATE TABLE TO STORE GAME DATA
    INSERT INTO game_data VALUES(p_tamanho, 0, 0);                                       -- INITIALIZE GAME DATA          
    CREATE TABLE campo_cell(coord point,
                                 cell_value TEXT,
                                 snake_pos INT);                                          -- CREATE TABLE FOR 
                                                                                          -- CONTROLING INTERFACE POSITIONS AND VALUES  
    CREATE TRIGGER f_replace_icon 
    AFTER UPDATE ON campo_cell 
    FOR EACH ROW EXECUTE FUNCTION t_replace_icon();
    SELECT CONCAT($$CREATE TABLE campo($$,
                  string_agg(concat(foo.col, series.col, $$ text$$), ', ') FILTER (WHERE fii.lin = series.col),
                  $$, row_numb serial)$$
                ) AS create_table,
           CONCAT($$INSERT INTO campo ($$,
                  string_agg(concat(foo.col, series.col), ', ') FILTER (WHERE fii.lin = series.col),
                  $$) VALUES $$, string_agg(fii.inst, ', ') FILTER (WHERE fii.lin = series.col)
                ) AS insert_table,
           CONCAT_WS(' ',$$INSERT INTO campo_cell$$,
                         $$SELECT UNNEST('$$, array_agg((series.col::TEXT||','||fii.lin::TEXT)), $$'::_point) , 'V'$$
                ) AS insert_cell
      FROM generate_series(1,p_tamanho) AS series(col)
     CROSS JOIN(
                    SELECT concat($$($$, string_agg(cobra.emj, ', ') OVER(), $$)$$) AS inst,
                           lines.lin
                      FROM (VALUES($$'🌿'$$)) AS cobra(emj),
                      generate_series(1,p_tamanho) AS lines(lin)
                ) AS fii,
           (VALUES('c_')) AS foo(col)
     GROUP BY fii.inst
      INTO rec_tab;
     EXECUTE rec_tab.create_table;                                          -- CREATE INTERFACE TABLE
     EXECUTE rec_tab.insert_table;                                          -- INSERT VALUES INTO INTERFACE TABLE
     EXECUTE rec_tab.insert_cell;                                           -- INSERT VALUES INTO THE TABLE FOR CONTROLING 
                                                                            -- INTERFACE POSITIONS AND VALUES
     SELECT ((random()*(p_tamanho-3))::int+2)
      INTO col;
    SELECT ((random() * (p_tamanho-3))::int+2)
      INTO lin;
    EXECUTE format($$UPDATE campo_cell 
                        SET cell_value = 'SH',
                            snake_pos = 0
                      WHERE coord[0] = %s 
                        AND coord[1] = %s$$, col, lin);
    EXECUTE format($$UPDATE campo_cell 
                        SET cell_value = 'SB',
                            snake_pos = 0
                      WHERE coord[0] = %s 
                        AND coord[1] = %s$$, col-1, lin);
    CALL random_fruit(1);
    UPDATE game_data 
       SET last_move = CASE WHEN (col/p_tamanho)<=0.5 THEN 'R'
                            ELSE 'L'
                        END;
END;
$procedure$;
CREATE OR REPLACE PROCEDURE random_fruit(p_force int)/*, tbl_name anyelement*/
/*RETURNS SETOF anyelement*/
LANGUAGE plpgsql
AS $function$
DECLARE
    valid_space bool = FALSE;
    col TEXT;
    lin INT;
BEGIN
     IF ((random()*4)::int IN (3,4) OR p_force = 1) AND EXISTS (SELECT FROM campo_cell WHERE cell_value = 'V')   -- CHECK IS THERES STILL VALID CELLS 
         THEN                                                                     -- CHECK IF FRUIT IS FORCEFUL
         WHILE valid_space = FALSE LOOP
           SELECT ((random()*(SELECT sz FROM game_data))::int+1)::TEXT
             INTO col;                                                                          -- GET RANDOM COLUMN 
           SELECT ((random()*(SELECT sz FROM game_data))::int+1)::TEXT
             INTO lin;                                                                          -- GET RANDOM LINE
           IF (SELECT cell_value 
                 FROM campo_cell 
                WHERE (coord ?- (col::TEXT||','||lin::TEXT)::point) = TRUE
                  AND  (coord ?| (col::TEXT||','||lin::TEXT)::point) = TRUE ) = 'V' THEN        -- CHECK IF COORDINATE IS A VALID CELL
                 valid_space = TRUE;
           END IF;
         END LOOP;
        EXECUTE format($$UPDATE campo_cell 
                            SET cell_value = 'F'
                          WHERE coord[0] = %s 
                            AND coord[1] = %s$$, col, lin);                                     -- UPDATE CELL TO FRUIT  
    END IF;
END;
$function$;
DROP FUNCTION mv_snake 
CREATE OR REPLACE FUNCTION mv_snake(/*col int, lin int,*/ direction TEXT, tbl_name anyelement)
RETURNS SETOF anyelement
LANGUAGE plpgsql
AS $function$
DECLARE
    v_sz bigint;
    v_coord point;
    v_coord_to point;
    v_coord_last point;
    v_scores record;
BEGIN
     SELECT COALESCE(NULLIF(direction,'O'),(SELECT last_move FROM game_data))
       INTO direction;
--    RAISE EXCEPTION '%', tbl_name;--(SELECT SQRT((col-v_coord[0])^2+(lin-v_coord[1])^2));
    SELECT sz
      FROM game_data
      INTO v_sz;                                                        -- GET FIELD SIZE
    SELECT coord
      FROM campo_cell
     WHERE cell_value = 'SH'
      INTO v_coord;                                                     -- GET HEAD COORDINATES 
    SELECT CASE direction
              WHEN 'U' THEN v_coord + ('0,-1')::point
              WHEN 'D' THEN v_coord + ('0,1')::point
              WHEN 'R' THEN v_coord + ('1,0')::point
              WHEN 'L' THEN v_coord + ('-1,0')::point
              ELSE v_coord + ('0,0')
           END 
    INTO v_coord_to;
    IF (v_coord_to[0] < 1 OR v_coord_to[0] > v_sz OR v_coord_to[1] < 1 OR v_coord_to[1] > v_sz)     -- CHECK IF MOVEMENT GOES OUT OF BOUNDRIES 
       OR EXISTS (SELECT
                    FROM campo_cell 
                   WHERE coord[0] = v_coord_to[0] 
                     AND coord[1] = v_coord_to[1]
                     AND cell_value = 'SB') THEN                        -- CHECK IF MOVEMENT COLIDES WITH BODY 
        EXECUTE (SELECT script FROM commands WHERE use = 'END GAME');
        INSERT INTO campo
        VALUES ('GAME OVER');
/*    
        RETURN QUERY
        SELECT * 
        FROM campo;*/
    ELSE 
    IF v_coord[0] != v_coord_to[0] OR v_coord[1] != v_coord_to[1] THEN 
/*      
    IF (SELECT SQRT((col-v_coord[0])^2+(lin-v_coord[1])^2)) != 1 THEN   -- CHECK IF MOVEMENT IS TO ADJACENT POSITION
      
       RAISE EXCEPTION 'MOVIMENTO INVALIDO';
    END IF;*/
        IF (SELECT cell_value 
              FROM campo_cell 
             WHERE campo_cell.coord[0] = v_coord_to[0]
               AND campo_cell.coord[1] = v_coord_to[1]) = 'F' THEN
            UPDATE game_data
               SET total_point = total_point+1,
                   grow_point = grow_point+1;                               -- UPDATE SCORES
            CALL random_fruit(1);
        END IF;
        SELECT coord /*,snake_pos*/
          FROM campo_cell
         WHERE cell_value = 'SB'
         ORDER BY campo_cell.snake_pos DESC
         LIMIT 1
          INTO v_coord_last;                                                -- GET LAST BODY PART
        UPDATE campo_cell
           SET cell_value = 'SH',
               snake_pos = 0
         WHERE campo_cell.coord[0] = v_coord_to[0]
           AND campo_cell.coord[1] = v_coord_to[1];                                   -- SET HEAD NEW POSITION TO HEAD
    --    RAISE EXCEPTION '%', v_coord;   
        UPDATE campo_cell
           SET cell_value = 'SB',
               snake_pos = -1
         WHERE campo_cell.coord[0] = v_coord[0]
           AND campo_cell.coord[1] = v_coord[1];                            -- SET HEAD OLD POSITION TO BODY PART
        SELECT total_point, grow_point 
          FROM game_data 
          INTO v_scores;
        IF v_scores.grow_point = 1 THEN                                    -- CHECK IF SNAKE NEEDS TO GROW
            UPDATE game_data
               SET grow_point = 0;
        ELSE 
            UPDATE campo_cell
               SET cell_value = 'V',
                   snake_pos = NULL
             WHERE campo_cell.coord[0] = v_coord_last[0]
               AND campo_cell.coord[1] = v_coord_last[1];                   -- SET LAST BODY PART OLD POSITION TO VALID SPACE
        END IF;
        WITH cte AS (
            SELECT ROW_NUMBER() OVER(ORDER BY snake_pos)-1 new_pos,
                   *
              FROM campo_cell
             WHERE cell_value = 'SB'
             ORDER BY snake_pos
        )UPDATE campo_cell 
            SET snake_pos = new_pos
           FROM cte
          WHERE (campo_cell.coord ?- cte.coord) = TRUE
            AND  (campo_cell.coord ?| cte.coord) = TRUE;                   -- ADJUSTS BODY PARTS SEQUENCE
--        CALL random_fruit(0);   
        UPDATE game_data
           SET last_move = direction
         WHERE last_move != direction;
        END IF;
    END IF;
    RETURN QUERY
    SELECT *
      FROM campo 
     ORDER BY row_numb;
END;
$function$;
CREATE TABLE commands(script TEXT, use TEXT)
INSERT INTO commands VALUES($$TRUNCATE TABLE campocampo;DROP TABLE game_data;DROP TABLE campo_cell;DROP TABLE score;$$, $$END GAME$$)
SELECT * FROM commands
CREATE TABLE msg(msg TEXT);
INSERT INTO msg VALUES($$GAME OVER$$);
DROP TABLE campo;DROP TABLE game_data;DROP TABLE campo_cell;
SELECT * FROM random_fruit(0); --, NULL::campo
SELECT * FROM mv_snake('L',NULL::campo)
CALL cria_campo(5);
SELECT * FROM campo ORDER BY row_numb;
SELECT * FROM campo_cell ORDER BY coord[0], coord[1];
SELECT * FROM game_data;
SELECT * FROM msg;
SELECT * FROM commands;
DO $a$
BEGIN
        /*EXECUTE format($$UPDATE campo_cell 
                            SET cell_value = 'SB',    AFTER UPDATE ON campo_cell 
                                snake_pos = 2
                          WHERE coord[0] = %s 
                            AND coord[1] = %s$$, 2, 5); */
END
$a$